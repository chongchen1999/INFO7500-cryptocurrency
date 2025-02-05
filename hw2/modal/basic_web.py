import modal

image = modal.Image.debian_slim().pip_install("fastapi[standard]")
app = modal.App(name="example-lifecycle-web", image=image)


@app.function()
@modal.web_endpoint(
    docs=True  # adds interactive documentation in the browser
)
def hello():
    return "Hello world!"


@app.function()
@modal.web_endpoint(docs=True)
def greet(user: str) -> str:
    return f"Hello {user}!"


@app.function()
@modal.web_endpoint(method="POST", docs=True)
def goodbye(data: dict) -> str:
    name = data.get("name") or "world"
    return f"Goodbye {name}!"


@app.cls()
class WebApp:
    @modal.enter()
    def startup(self):
        from datetime import datetime, timezone

        print("🏁 Starting up!")
        self.start_time = datetime.now(timezone.utc)

    @modal.web_endpoint(docs=True)
    def web(self):
        from datetime import datetime, timezone

        current_time = datetime.now(timezone.utc)
        return {"start_time": self.start_time, "current_time": current_time}


@app.function(gpu="h100")
@modal.web_endpoint(requires_proxy_auth=True, docs=False)
def expensive_secret():
    return "I didn't care for 'The Godfather'. It insists upon itself."
