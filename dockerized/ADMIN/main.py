from fastapi import APIRouter, Depends
from fastapi.responses import HTMLResponse
from sqlalchemy.ext.asyncio import AsyncSession
from .dependencies import get_current_user  # JWT authentication dependency
from .database import get_db
from .models import User
from fastapi.templating import Jinja2Templates # type: ignore
from starlette.requests import Request # type: ignore

# Create FastAPI app
app = FastAPI()

# Dependency for DB Session
async def get_db():
    async with SessionLocal() as session:
        yield session

# Import and include routers
from .routes.auth import router as auth_router # type: ignore
from .routes.main import router as main_router # type: ignore

app.include_router(auth_router, prefix="/auth", tags=["auth"])
app.include_router(main_router, prefix="/main", tags=["main"])

# Startup Event
@app.on_event("startup")
async def startup():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

# Root Endpoint
@app.get("/")
async def root():
    return {"message": "Welcome to FastAPI App"}

router = APIRouter()
templates = Jinja2Templates(directory="templates")

@router.get("/", response_class=HTMLResponse)
async def index(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

@router.get("/profile", response_class=HTMLResponse)
async def profile(request: Request, current_user: User = Depends(get_current_user)):
    return templates.TemplateResponse("profile.html", {"request": request, "name": current_user.name})
