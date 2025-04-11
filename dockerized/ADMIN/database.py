from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker
from .models import Base
import os

DATABASE_URL = f"postgresql+asyncpg://{os.environ['suser']}:{os.environ['spassword']}@{os.environ['shost']}:{os.environ['sport']}/{os.environ['sdatabase']}"

engine = create_async_engine(DATABASE_URL, echo=True)
async_session = sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)

async def get_db():
    async with async_session() as session:
        yield session

async def init_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
