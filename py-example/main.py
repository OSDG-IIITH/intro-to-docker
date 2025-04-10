import os
import uvicorn
from dotenv import load_dotenv

load_dotenv()

if __name__ == "__main__":
	uvicorn.run(
		"src:app",
		host=os.getenv("APP_HOST", "0.0.0.0"),
		port=int(os.getenv("PORT", "5000")),
		reload=os.getenv("RELOAD", "1") == "1",
	)
