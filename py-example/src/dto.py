from datetime import datetime

from pydantic import BaseModel


class User(BaseModel):
	id: str
	email: str
	username: str
	password: str
	created_at: datetime
