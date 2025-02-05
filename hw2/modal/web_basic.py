import modal

# Create a container image with FastAPI installed
image = modal.Image.debian_slim().pip_install("fastapi[standard]")

# Define a Modal app
app = modal.App(name="chongchen-web-basic", image=image)

# Basic web endpoint
@app.function()
@modal.web_endpoint(docs=True)
def hello():
    return "Hello, world!"

# Web endpoint with query parameter
@app.function()
@modal.web_endpoint(docs=True)
def greet(user: str) -> str:
    return f"Hello {user}!"

# Web endpoint with JSON body
@app.function()
@modal.web_endpoint(method="POST", docs=True)
def goodbye(data: dict) -> str:
    name = data.get("name", "world")
    return f"Goodbye {name}!"

# Web endpoint with class-based initialization
@app.cls()
class WebApp:
    @modal.enter()
    def startup(self):
        from datetime import datetime, timezone
        self.start_time = datetime.now(timezone.utc)

    @modal.web_endpoint(docs=True)
    def status(self):
        from datetime import datetime, timezone
        return {
            "start_time": self.start_time.isoformat(),
            "current_time": datetime.now(timezone.utc).isoformat()
        }

# Secure web endpoint with proxy authentication
@app.function()
@modal.web_endpoint(requires_proxy_auth=True, docs=False)
def secret():
    return "This is a protected endpoint."
