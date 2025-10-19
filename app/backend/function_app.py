import azure.functions as func
import logging

app = func.FunctionApp()

@app.function_name(name="HttpExampleRoot")
@app.route(route="")
def http_example(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("HTTP trigger processed a request.")
    return func.HttpResponse(
        "¡Hola, Azure Functions está funcionando!",
        status_code=200,
        mimetype="text/plain"
    )
