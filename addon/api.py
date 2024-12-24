from fastapi import APIRouter

router = APIRouter()

@router.post("/api/process_update")
async def process_update(request):
    """Handle process updates from clients"""

@router.post("/api/extend_time")
async def extend_time(request):
    """Handle time extension requests"""

@router.get("/api/limits")
async def get_limits(request):
    """Get current limits for client""" 