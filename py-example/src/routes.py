import re
import os
import aiofiles
from typing import Annotated, Literal, Optional, cast
from fastapi import (
	Body,
	Cookie,
	Depends,
	Form,
	HTTPException,
	Response,
	UploadFile,
)
from fastapi.requests import Request
from fastapi.responses import RedirectResponse, FileResponse
from pydantic import BaseModel
from bcrypt import hashpw, gensalt, checkpw
from uuid import uuid4
from asyncpg import Record

from . import db
from .rd import redis
from .app import app
from .templ import templ
from .auth import User, auth


@app.get("/")
async def index(
	req: Request, user: Annotated[User, Depends(auth)], db: db.Database
):
	posts = await db.fetch(
		"""
			select
				p.id,
				p.text,
				p.image_path,
				p.user_id,
				p.created_at,
				u.username as user_name,
				coalesce((select count(*) from post_likes where post_id = p.id), 0) as num_likes,
				coalesce((select count(comments.id) from comments where post_id = p.id), 0) as num_comments,
				exists(select 1 from post_likes where user_id = $1 and post_id = p.id) as user_liked
			from posts p inner join users u on u.id = p.user_id
			order by p.created_at desc;
		""",
		user.id,
	)

	return templ.TemplateResponse(
		req, "index.html", dict(username=user.username, posts=posts)
	)


@app.get("/auth")
async def auth_get(req: Request):
	return templ.TemplateResponse(req, "auth.html")


class AuthBody(BaseModel):
	email: str
	password: str
	username: Optional[str] = None
	action: Literal["login"] | Literal["register"]


@app.post("/auth")
async def auth_post(
	req: Request,
	body: Annotated[AuthBody, Form()],
	db: db.Database,
):
	if body.action == "register" and body.username is None:
		return templ.TemplateResponse(
			req,
			"auth.html",
			dict(message="Username should be set"),
			400,
		)

	if (
		re.compile(
			r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
		).match(body.email)
		is None
	):
		return templ.TemplateResponse(
			req,
			"auth.html",
			dict(message="Invalid email"),
			400,
		)

	user = cast(
		Record | None,
		await db.fetchrow(
			"select * from users where email = $1", body.email
		),
	)
	user_id: str | None = None
	match (user, body.action):
		case (None, "login"):
			return templ.TemplateResponse(
				req,
				"auth.html",
				dict(message="User with this email does not exist"),
				400,
			)
		case (None, "register"):
			userid_rec = cast(
				Record,
				await db.fetchrow(
					"insert into users(email, username, password) values ($1, $2, $3) returning id",
					body.email,
					cast(str, body.username).strip(),
					hashpw(body.password.encode(), gensalt()).decode(),
				),
			)
			user_id = userid_rec["id"]
		case (_, "register"):
			return templ.TemplateResponse(
				req,
				"auth.html",
				dict(message="User with this email already exists"),
				400,
			)
		case (u, "login"):
			if not checkpw(
				body.password.encode(), u["password"].encode()
			):
				return templ.TemplateResponse(
					req,
					"auth.html",
					dict(message="Invalid password"),
					400,
				)
			user_id = u["id"]
	if user_id is None:
		return templ.TemplateResponse(
			req,
			"auth.html",
			dict(message="Could not log you in :: Unexpected error"),
			500,
		)
	session_id = str(uuid4())
	await redis.set(f"session:{session_id}", str(user_id))
	res = RedirectResponse("/", 302)
	res.set_cookie("session_id", session_id)
	return res


@app.route("/logout", methods=["GET", "POST", "DELETE"])
async def logout(session_id: Annotated[str | None, Cookie()] = None):
	res = RedirectResponse("/auth", 302)
	if session_id is not None:
		await redis.delete(f"session:{session_id}")
	res.delete_cookie("session_id")
	return res


@app.get("/new")
async def post_get(user: Annotated[User, Depends(auth)], req: Request):
	return templ.TemplateResponse(
		req, "new.html", dict(username=user.username)
	)


@app.post("/new")
async def post_post(
	user: Annotated[User, Depends(auth)],
	req: Request,
	db: db.Database,
	text: Annotated[str, Form()],
	image: UploadFile | None = None,
):
	if not text.strip():
		return templ.TemplateResponse(
			req,
			"new.html",
			dict(
				username=user.username,
				message="Please enter some content",
			),
		)
	post_id = str(uuid4())
	image_path: str | None = None
	print(image)
	if image is not None and image.size is not None and image.size > 0:
		if (
			image.content_type != "image/png"
			and image.content_type != "image/jpeg"
		):
			return templ.TemplateResponse(
				req,
				"new.html",
				dict(
					username=user.username,
					message="Only PNG and JPEG images are allowed",
				),
			)
		if image.size > 10 * 1024 * 1024:
			return templ.TemplateResponse(
				req,
				"new.html",
				dict(
					username=user.username,
					message="Images must be <= 10MiB in size",
				),
			)
		image_path = f"{post_id}.{'png' if image.content_type == 'image/png' else 'jpg'}"
		async with aiofiles.open(
			os.path.join(
				os.getcwd(),
				"post_images",
				image_path,
			),
			"wb",
		) as f:
			# there's probably a better way to do this
			await f.write(await image.read())
		image_path = f"/post_images/{image_path}"
	await db.fetchrow(
		"insert into posts (id, text, image_path, user_id) values ($1, $2, $3, $4) returning id",
		post_id,
		text,
		image_path,
		user.id,
	)
	return RedirectResponse(f"/{post_id}", 302)


@app.get("/profile")
async def profile_route(user: Annotated[User, Depends(auth)]):
	print(user)
	return RedirectResponse(f"/@{user.username}")


@app.get("/{param}")
async def post_or_user(
	param: str,
	req: Request,
	db: db.Database,
	user: Annotated[User, Depends(auth)],
):
	match param[0]:
		case "@":
			posts = await db.fetch(
				"""
					select
						p.id,
						p.text,
						p.image_path,
						p.user_id,
						p.created_at,
						u.username as user_name,
						coalesce((select count(*) from post_likes where post_id = p.id), 0) as num_likes,
						coalesce((select count(comments.id) from comments where post_id = p.id), 0) as num_comments,
						exists(select 1 from post_likes where user_id = $2 and post_id = p.id) as user_liked
					from posts p inner join users u on u.id = p.user_id
					where u.username = $1
					order by created_at desc;
				""",
				param[1:],
				user.id,
			)

			return templ.TemplateResponse(
				req,
				"index.html",
				dict(
					username=user.username,
					posts=posts,
					ofuser=param[1:],
				),
			)
		case _:
			try:
				post = await db.fetchrow(
					"""
						select
							p.id,
							p.text,
							p.image_path,
							p.user_id,
							p.created_at,
							u.username as user_name,
							coalesce((select count(*) from post_likes where post_id = p.id), 0) as num_likes,
							coalesce((select count(comments.id) from comments where post_id = p.id), 0) as num_comments,
							exists(select 1 from post_likes where user_id = $2 and post_id = p.id) as user_liked
						from posts p inner join users u on u.id = p.user_id
						where p.id = $1 order by p.created_at desc;
					""",
					param,
					user.id,
				)
				if post is None:
					raise HTTPException(404, "Post not found")
				comments = await db.fetch(
					"""
						select c.*, u.username as user_name,
							coalesce((select count(*) from comment_likes where comment_id = c.id), 0) as num_likes,
							exists(select 1 from comment_likes where user_id = $2 and comment_id = c.id) as user_liked
						from comments c inner join users u on u.id = c.user_id where post_id = $1
						order by c.created_at desc;
					""",
					post["id"],
					user.id,
				)
				return templ.TemplateResponse(
					req, "post.html", dict(post=post, comments=comments)
				)
			except:
				return HTTPException(404, "Not found")


class CommentPayload(BaseModel):
	post_id: str
	text: str


@app.post("/comment")
async def comment(
	comment: Annotated[CommentPayload, Form()],
	db: db.Database,
	user: Annotated[User, Depends(auth)],
):
	post = await db.fetchrow(
		"select id from posts where id = $1", comment.post_id
	)
	if post is None:
		raise HTTPException(404, "Not found")
	if not comment.text.strip():
		raise HTTPException(400, "Please enter some text")
	await db.execute(
		"insert into comments(text, post_id, user_id) values ($1, $2, $3)",
		comment.text.strip(),
		comment.post_id,
		user.id,
	)
	return RedirectResponse(f"/{comment.post_id}", 302)


@app.get("/post_images/{image}")
async def post_image(image: str):
	if not (
		image.endswith(".png")
		or image.endswith(".jpg")
		or image.endswith(".jpeg")
	):
		raise HTTPException(404, "Image not found")
	return FileResponse(os.path.join(os.getcwd(), "post_images", image))


class LikePayload(BaseModel):
	id: str
	type: Literal["post"] | Literal["comment"]
	to_like: bool


@app.patch("/like")
async def like(
	body: Annotated[LikePayload, Body()],
	user: Annotated[User, Depends(auth)],
	db: db.Database,
):
	# sql injection 🤓
	item = await db.fetchrow(
		f"select id from {body.type}s where id = $1", body.id
	)
	if item is None:
		raise HTTPException(404, "Not found")
	if body.to_like:
		await db.execute(
			f"insert into {body.type}_likes(user_id, {body.type}_id) values ($1, $2);",
			user.id,
			body.id,
		)
	else:
		await db.execute(
			f"delete from {body.type}_likes where user_id = $1 and {body.type}_id = $2;",
			user.id,
			body.id,
		)
	return Response(None, 204)
