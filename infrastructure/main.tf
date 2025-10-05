# Configure the Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# 1. Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-note-taker-serverless"
  location = "East US"
}

# 2. Azure Cosmos DB Account (Database Service)
resource "azurerm_cosmosdb_account" "db_account" {
  # NOTE: Must be globally unique (change the name prefix!)
  name                = "notetaker-cosmos-db-987654" 
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB" # Defines it as a Core (SQL) API account

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.rg.location
    failover_priority = 0
  }
}

# 2.1. Cosmos DB SQL Database
resource "azurerm_cosmosdb_sql_database" "db" {
  name                = "NoteDb"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.db_account.name
  throughput          = 400
}

# 2.2. Cosmos DB Container (Table)
resource "azurerm_cosmosdb_sql_container" "notes_container" {
  name                = "Notes"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.db_account.name
  database_name       = azurerm_cosmosdb_sql_database.db.name
  throughput          = 400
  
  # 🎯 FIX: Changed 'partition_key_path' to 'partition_key_paths' (plural, array)
  partition_key_paths  = ["/category"] 
}

# 3. Azure Storage Account (Required for Functions)
resource "azurerm_storage_account" "storage" {
  # NOTE: Must be globally unique (change the name prefix!)
  name                     = "notetakerstorage987654" 
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# 4. Azure Function App Service Plan (Consumption Plan - Serverless)
resource "azurerm_service_plan" "function_plan" {
  name                = "plan-note-taker"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption/Serverless Plan
}

# 5. Azure Function App (Backend API)
resource "azurerm_linux_function_app" "function_app" {
  # NOTE: Must be globally unique (change the name prefix!)
  name                       = "func-note-taker-app-987654" 
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  service_plan_id            = azurerm_service_plan.function_plan.id
  storage_account_name       = azurerm_storage_account.storage.name
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key

  site_config {
    application_stack {
      python_version = "3.9"
    }
  }

  # Application Settings (Environment Variables)
  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "python"
    "COSMOS_ENDPOINT"          = azurerm_cosmosdb_account.db_account.endpoint
    "COSMOS_KEY"               = azurerm_cosmosdb_account.db_account.primary_key
    "WEBSITE_RUN_FROM_PACKAGE" = "1" 
    "CORS_ALLOWED_ORIGINS"     = "*" # Ansible will secure this later
  }
}

# 6. Azure Static Web App (Frontend Hosting)
resource "azurerm_static_web_app" "static_app" {
  name                = "swa-note-taker-app"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  
  # Note: A simple `azurerm_static_web_app` block is sufficient for infrastructure creation.
  # The actual linking to GitHub/Code is handled by the Azure SWA service after creation.
}

# Terraform Outputs
output "function_app_default_host_name" {
  value       = azurerm_linux_function_app.function_app.default_hostname
  description = "The hostname for the Azure Function App (API base URL)"
}

output "static_web_app_default_host_name" {
  value       = azurerm_static_web_app.static_app.default_hostname
  description = "The hostname for the Azure Static Web App (Frontend URL)"
}