from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from . import db
from .rd import redis


@asynccontextmanager
async def lifespan(_: ...):
	print("Establishing a connection to the database")
	await db.connect()
	yield
	print("Disconnecting from the database")
	await db.disconnect()
	print("Disconnecting from redis")
	await redis.aclose()


app = FastAPI(lifespan=lifespan)
app.mount("/static", StaticFiles(directory="static"), name="static")
