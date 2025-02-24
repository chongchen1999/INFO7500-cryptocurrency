from modal import App, Image, Stub
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse

image = Image.debian_slim().pip_install("fastapi[standard]")
app = App(name="webapp")
stub = Stub("webapp", image=image)

html_content = """
<!DOCTYPE html>
<html>
<head>
    <title>Simple Modal WebApp</title>
</head>
<body>
    <h2>Type something:</h2>
    <input type="text" id="userInput" oninput="updateText()">
    <h3>Replicated Text:</h3>
    <p id="outputText"></p>

    <script>
        function updateText() {
            document.getElementById("outputText").innerText = document.getElementById("userInput").value;
        }
    </script>
</body>
</html>
"""

@app.function()
@FastAPI()
def fastapi_app():
    app = FastAPI()
    
    @app.get("/", response_class=HTMLResponse)
    def serve():
        return html_content
    
    return app
