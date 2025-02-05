import modal

image = modal.Image.debian_slim().pip_install("fastapi[standard]")
app = modal.App(name="example-basic-web", image=image)

@app.function()
@modal.web_endpoint(docs=True)  # no authentication flag set
def hello():
    return "Hello world!"
