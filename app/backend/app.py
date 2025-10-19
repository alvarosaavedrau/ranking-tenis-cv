import azure.functions as func
import logging
import json
import os
from datetime import datetime
from azure.cosmos import CosmosClient, exceptions

# Configuración de Cosmos DB desde variables de entorno
COSMOS_ENDPOINT = os.environ.get("COSMOS_DB_ENDPOINT")
COSMOS_KEY = os.environ.get("COSMOS_DB_KEY")
DATABASE_NAME = os.environ.get("COSMOS_DB_DATABASE_NAME")
CONTAINER_NAME = os.environ.get("COSMOS_DB_CONTAINER_NAME")

# Cliente de Cosmos DB
cosmos_client = CosmosClient(COSMOS_ENDPOINT, COSMOS_KEY)
database = cosmos_client.get_database_client(DATABASE_NAME)
container = database.get_container_client(CONTAINER_NAME)

# Inicializar la aplicación de Functions
app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

# ==================== FUNCIÓN 1: Crear nuevo partido ====================
@app.route(route="partidos", methods=["POST"])
def crear_partido(req: func.HttpRequest) -> func.HttpResponse:
    """
    Endpoint POST para crear un nuevo partido de tenis
    Body esperado: {
        "jugador1": "Rafael Nadal",
        "jugador2": "Roger Federer",
        "sets_jugador1": 3,
        "sets_jugador2": 1,
        "juegos": "6-4, 6-3, 6-7, 6-2",
        "fecha": "2025-10-19",
        "ganador": "jugador1"
    }
    """
    logging.info('Creando nuevo partido de tenis')
    
    try:
        # Parsear el body JSON
        req_body = req.get_json()
        
        # Validar campos requeridos
        campos_requeridos = ["jugador1", "jugador2", "sets_jugador1", "sets_jugador2", "ganador"]
        for campo in campos_requeridos:
            if campo not in req_body:
                return func.HttpResponse(
                    json.dumps({"error": f"Campo requerido '{campo}' no encontrado"}),
                    status_code=400,
                    mimetype="application/json"
                )
        
        # Crear el documento para Cosmos DB
        partido = {
            "id": f"partido-{datetime.now().timestamp()}",  # ID único
            "jugador1": req_body.get("jugador1"),
            "jugador2": req_body.get("jugador2"),
            "sets_jugador1": int(req_body.get("sets_jugador1")),
            "sets_jugador2": int(req_body.get("sets_jugador2")),
            "juegos": req_body.get("juegos", ""),
            "fecha": req_body.get("fecha", datetime.now().strftime("%Y-%m-%d")),
            "ganador": req_body.get("ganador"),
            "notas": req_body.get("notas", ""),
            "created_at": datetime.now().isoformat()
        }
        
        # Insertar en Cosmos DB
        created_item = container.create_item(body=partido)
        
        logging.info(f'Partido creado con ID: {created_item["id"]}')
        
        return func.HttpResponse(
            json.dumps(created_item),
            status_code=201,
            mimetype="application/json"
        )
        
    except ValueError:
        return func.HttpResponse(
            json.dumps({"error": "Body JSON inválido"}),
            status_code=400,
            mimetype="application/json"
        )
    except exceptions.CosmosHttpResponseError as e:
        logging.error(f'Error de Cosmos DB: {str(e)}')
        return func.HttpResponse(
            json.dumps({"error": f"Error en la base de datos: {str(e)}"}),
            status_code=500,
            mimetype="application/json"
        )
    except Exception as e:
        logging.error(f'Error inesperado: {str(e)}')
        return func.HttpResponse(
            json.dumps({"error": f"Error interno: {str(e)}"}),
            status_code=500,
            mimetype="application/json"
        )


# ==================== FUNCIÓN 2: Listar todos los partidos ====================
@app.route(route="partidos", methods=["GET"])
def listar_partidos(req: func.HttpRequest) -> func.HttpResponse:
    """
    Endpoint GET para obtener todos los partidos
    Opcionalmente puedes filtrar por query params:
    ?jugador=Rafael (busca partidos donde juegue ese jugador)
    """
    logging.info('Listando todos los partidos')
    
    try:
        # Parámetro opcional para filtrar por jugador
        jugador_filtro = req.params.get('jugador')
        
        # Query de Cosmos DB
        if jugador_filtro:
            query = """
                SELECT * FROM c 
                WHERE CONTAINS(LOWER(c.jugador1), LOWER(@jugador)) 
                   OR CONTAINS(LOWER(c.jugador2), LOWER(@jugador))
                ORDER BY c.fecha DESC
            """
            parameters = [{"name": "@jugador", "value": jugador_filtro}]
            items = list(container.query_items(
                query=query,
                parameters=parameters,
                enable_cross_partition_query=True
            ))
        else:
            # Obtener todos los partidos ordenados por fecha
            query = "SELECT * FROM c ORDER BY c.fecha DESC"
            items = list(container.query_items(
                query=query,
                enable_cross_partition_query=True
            ))
        
        logging.info(f'Se encontraron {len(items)} partidos')
        
        return func.HttpResponse(
            json.dumps(items),
            status_code=200,
            mimetype="application/json"
        )
        
    except exceptions.CosmosHttpResponseError as e:
        logging.error(f'Error de Cosmos DB: {str(e)}')
        return func.HttpResponse(
            json.dumps({"error": f"Error en la base de datos: {str(e)}"}),
            status_code=500,
            mimetype="application/json"
        )
    except Exception as e:
        logging.error(f'Error inesperado: {str(e)}')
        return func.HttpResponse(
            json.dumps({"error": f"Error interno: {str(e)}"}),
            status_code=500,
            mimetype="application/json"
        )


# ==================== FUNCIÓN 3: Obtener un partido específico ====================
@app.route(route="partidos/{id}", methods=["GET"])
def obtener_partido(req: func.HttpRequest) -> func.HttpResponse:
    """
    Endpoint GET para obtener un partido específico por ID
    """
    partido_id = req.route_params.get('id')
    logging.info(f'Obteniendo partido con ID: {partido_id}')
    
    try:
        # Leer el partido de Cosmos DB
        item = container.read_item(item=partido_id, partition_key=partido_id)
        
        return func.HttpResponse(
            json.dumps(item),
            status_code=200,
            mimetype="application/json"
        )
        
    except exceptions.CosmosResourceNotFoundError:
        return func.HttpResponse(
            json.dumps({"error": f"Partido con ID '{partido_id}' no encontrado"}),
            status_code=404,
            mimetype="application/json"
        )
    except exceptions.CosmosHttpResponseError as e:
        logging.error(f'Error de Cosmos DB: {str(e)}')
        return func.HttpResponse(
            json.dumps({"error": f"Error en la base de datos: {str(e)}"}),
            status_code=500,
            mimetype="application/json"
        )
    except Exception as e:
        logging.error(f'Error inesperado: {str(e)}')
        return func.HttpResponse(
            json.dumps({"error": f"Error interno: {str(e)}"}),
            status_code=500,
            mimetype="application/json"
        )


# ==================== FUNCIÓN 4: Eliminar un partido ====================
@app.route(route="partidos/{id}", methods=["DELETE"])
def eliminar_partido(req: func.HttpRequest) -> func.HttpResponse:
    """
    Endpoint DELETE para eliminar un partido por ID
    """
    partido_id = req.route_params.get('id')
    logging.info(f'Eliminando partido con ID: {partido_id}')
    
    try:
        # Eliminar el partido de Cosmos DB
        container.delete_item(item=partido_id, partition_key=partido_id)
        
        return func.HttpResponse(
            json.dumps({"message": f"Partido con ID '{partido_id}' eliminado correctamente"}),
            status_code=200,
            mimetype="application/json"
        )
        
    except exceptions.CosmosResourceNotFoundError:
        return func.HttpResponse(
            json.dumps({"error": f"Partido con ID '{partido_id}' no encontrado"}),
            status_code=404,
            mimetype="application/json"
        )
    except exceptions.CosmosHttpResponseError as e:
        logging.error(f'Error de Cosmos DB: {str(e)}')
        return func.HttpResponse(
            json.dumps({"error": f"Error en la base de datos: {str(e)}"}),
            status_code=500,
            mimetype="application/json"
        )
    except Exception as e:
        logging.error(f'Error inesperado: {str(e)}')
        return func.HttpResponse(
            json.dumps({"error": f"Error interno: {str(e)}"}),
            status_code=500,
            mimetype="application/json"
        )


# ==================== FUNCIÓN 5: Health Check ====================
@app.route(route="health", methods=["GET"])
def health_check(req: func.HttpRequest) -> func.HttpResponse:
    """
    Endpoint simple para verificar que la API está funcionando
    """
    logging.info('Health check solicitado')
    
    return func.HttpResponse(
        json.dumps({
            "status": "ok",
            "message": "API de Tenis funcionando correctamente",
            "timestamp": datetime.now().isoformat()
        }),
        status_code=200,
        mimetype="application/json"
    )

