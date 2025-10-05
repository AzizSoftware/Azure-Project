import logging
import json
import azure.functions as func
from azure.cosmos import CosmosClient, PartitionKey, exceptions
import os
import uuid

# --- Cosmos DB Setup (Environment Variables) ---
# NOTE: These variables are set by Terraform/Ansible
COSMOS_ENDPOINT = os.environ.get("COSMOS_ENDPOINT")
COSMOS_KEY = os.environ.get("COSMOS_KEY")
DATABASE_NAME = "NoteDb"
CONTAINER_NAME = "Notes"
PARTITION_KEY_PATH = "/category" # Simple single partition key for this small project

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    # Initialize Cosmos DB Client
    try:
        client = CosmosClient(COSMOS_ENDPOINT, COSMOS_KEY)
        database = client.get_database_client(DATABASE_NAME)
        container = database.get_container_client(CONTAINER_NAME)
    except Exception as e:
        logging.error(f"Cosmos DB Connection Error: {e}")
        return func.HttpResponse(
             "Database connection error.",
             status_code=500
        )

    try:
        if req.method == 'GET':
            # --- GET ALL NOTES ---
            # Cosmos DB SQL query
            query = "SELECT * FROM c"
            items = list(container.query_items(query=query, enable_cross_partition_query=True))
            return func.HttpResponse(
                json.dumps(items),
                mimetype="application/json"
            )

        elif req.method == 'POST':
            # --- CREATE NEW NOTE ---
            req_body = req.get_json()
            title = req_body.get('title')
            content = req_body.get('content')

            if title and content:
                new_note = {
                    "id": str(uuid.uuid4()),
                    "title": title,
                    "content": content,
                    "category": "General", # Required by the simple PartitionKey setup
                    "timestamp": func.get_current_utc_time().isoformat()
                }
                container.create_item(body=new_note)
                return func.HttpResponse(
                    "Note created successfully.",
                    status_code=201
                )
            else:
                return func.HttpResponse(
                     "Please pass a title and content in the request body.",
                     status_code=400
                )

        elif req.method == 'DELETE':
            # --- DELETE NOTE ---
            # Expecting a note ID in the query string or URL path (simplified to query string for this example)
            note_id = req.params.get('id') 
            
            if note_id:
                # To delete, we need both the id and the partition key value (category in this case)
                # Since the frontend only sends the ID, a lookup is needed, or we assume a fixed category.
                # For simplicity and efficiency in Cosmos DB, we will assume all notes belong to "General"
                # in the current simple design.
                container.delete_item(item=note_id, partition_key="General")
                return func.HttpResponse(
                    f"Note with id '{note_id}' deleted.",
                    status_code=200
                )
            else:
                return func.HttpResponse(
                     "Please pass a note 'id' in the query string for deletion.",
                     status_code=400
                )

        else:
            return func.HttpResponse(
                "Method not supported.",
                status_code=405
            )

    except ValueError:
        return func.HttpResponse(
             "Request body is not valid JSON.",
             status_code=400
        )
    except exceptions.CosmosResourceNotFoundError:
        return func.HttpResponse(
             "Note not found.",
             status_code=404
        )
    except Exception as e:
        logging.error(f"An unexpected error occurred: {e}")
        return func.HttpResponse(
             f"An error occurred: {e}",
             status_code=500
        )