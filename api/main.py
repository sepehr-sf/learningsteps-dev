import logging
import time

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.responses import RedirectResponse
from prometheus_client import Counter, Histogram, make_asgi_app
from routers.journal_router import router as journal_router
from starlette.requests import Request

load_dotenv()

# Configure basic console logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

# Prometheus HTTP metrics
REQUEST_COUNT = Counter(
    "learningsteps_http_requests_total",
    "Total number of HTTP requests",
    ["method", "endpoint", "status"]
)

REQUEST_LATENCY = Histogram(
    "learningsteps_http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["method", "endpoint"]
)

app = FastAPI(title="LearningSteps API 🚀", description="A simple learning journal API for tracking daily work, struggles, and intentions")
# Expose Prometheus metrics
app.mount("/metrics", make_asgi_app())

app.include_router(journal_router)
# Kubernetes health-check endpoint.
# Returns HTTP 200 when the FastAPI application is responsive.
@app.get("/health", include_in_schema=False)
def health():
    return {"status": "healthy"}

@app.get("/", include_in_schema=False)
def root():
    return RedirectResponse(url="/docs")

@app.middleware("http")
async def prometheus_metrics(request: Request, call_next):
    start_time = time.perf_counter()

    response = await call_next(request)

    duration = time.perf_counter() - start_time

    # Avoid counting Prometheus' own scraping requests
    if request.url.path != "/metrics":
        route = request.scope.get("route")
        endpoint = route.path if route else "unmatched"

        REQUEST_COUNT.labels(
            method=request.method,
            endpoint=endpoint,
            status=response.status_code
        ).inc()

        REQUEST_LATENCY.labels(
            method=request.method,
            endpoint=endpoint
        ).observe(duration)

    return response

# Log when the app starts
logger.info("LearningSteps API started successfully")