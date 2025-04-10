from typing import Annotated
from fastapi import Cookie
from asyncpg import Record

from . import db
from .rd import redis
from .dto import User


class NotLoggedInException(Exception):
	message: str | None

	def __init__(self, message: str | None = None):
		self.message = message


async def auth(
	db: db.Database, session_id: Annotated[str | None, Cookie()] = None
):
	if session_id is None:
		raise NotLoggedInException()
	user_id = await redis.get(f"session:{session_id}")
	if not user_id:
		raise NotLoggedInException("Invalid session cookie")
	user: Record | None = await db.fetchrow(
		"select * from users where id = $1", user_id.decode()
	)
	if not user:
		await redis.delete(f"session:{session_id}")
		raise NotLoggedInException("Invalid user")
	return User(
		id=str(user["id"]),
		email=user["email"],
		username=user["username"],
		password=user["password"],
		created_at=user["created_at"],
	)
