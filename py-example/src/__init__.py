from fastapi import Request
from .app import app
from . import auth
from . import routes
from .templ import templ


@app.exception_handler(auth.NotLoggedInException)
def nlie_handler(req: Request, ex: auth.NotLoggedInException):
	res = templ.TemplateResponse(
		req,
		"auth.html",
		dict(message=ex.message) if ex.message else {},
		status_code=401 if ex.message else 200,
	)
	res.delete_cookie("session_id")
	return res
