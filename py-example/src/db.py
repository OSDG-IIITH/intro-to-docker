from typing import Annotated, cast
import asyncpg
from asyncpg.connection import Connection
import os

from fastapi import Depends

_db: Connection | None = None


async def db():
	return await connect()


Database = Annotated[Connection, Depends(db)]


async def connect():
	global _db
	if _db is None:
		_db = await asyncpg.connect(
			os.getenv(
				"DATABASE_URL",
				"postgres://postgres:postgres@localhost:5432/instabad",
			)
		)
	return cast(Connection, _db)


async def disconnect():
	global _db
	if _db:
		await _db.close()
		_db = None
