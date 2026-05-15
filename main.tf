terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "> 4.23.0"
    }
  }

 backend "azurerm" {
    resource_group_name  = "RG_Terraform_Ucb"
    storage_account_name = "tfstatekathy2026"
    container_name       = "tfstate"
    key                  = "terraform.pai.tfstate"
  }
} 

provider "azurerm" {
  features {}
  # Credenciales de Azure
  subscription_id = "7a47fb70-5fda-4363-851f-745192ec6055"
  tenant_id       = "cc28633f-12b8-46cb-bc15-951dae239b4d"
  client_id       = "91c26c1d-10a3-4b60-be32-487e608a5396"
  client_secret   = ""
}
 
# 1. Grupo de recursos
resource "azurerm_resource_group" "rg" {
  name     = "gr-sisger-dwpai-343224"
  location = "Brazil South"
}
 
# 2. Storage Account (Data Lake Gen 2)
resource "azurerm_storage_account" "sa" {
  name                     = "saucbpai99kathy01" 
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = "true"
}
 
# 3. Contenedor Bronze
resource "azurerm_storage_container" "datalake-pai" {
  name                  = "bronze"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "blob"
}

# =========================================================
# 4. SUBIDA DE LOS 6 ARCHIVOS AL DATA LAKE (CAPA BRONZE)
# =========================================================

# --- Catálogos (Dimensiones) ---
resource "azurerm_storage_blob" "cat_departamentos" {
  name                   = "catalogo_departamentos.csv"
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_container.datalake-pai.name
  type                   = "Block"
  source                 = "datos_crudos/catalogo_departamentos.csv"
}

resource "azurerm_storage_blob" "cat_establecimientos" {
  name                   = "catalogo_establecimientos.csv"
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_container.datalake-pai.name
  type                   = "Block"
  source                 = "datos_crudos/catalogo_establecimientos.csv"
}

resource "azurerm_storage_blob" "cat_vacunas" {
  name                   = "catalogo_vacunas_pai.csv"
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_container.datalake-pai.name
  type                   = "Block"
  source                 = "datos_crudos/catalogo_vacunas_pai.csv"
}

# --- Transaccionales (Hechos) ---
resource "azurerm_storage_blob" "vacunacion_lpz" {
  name                   = "vacunacion_la_paz.csv"
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_container.datalake-pai.name
  type                   = "Block"
  source                 = "datos_crudos/vacunacion_la_paz.csv"
}

resource "azurerm_storage_blob" "vacunacion_movil" {
  name                   = "vacunacion_rural_movil.csv"
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_container.datalake-pai.name
  type                   = "Block"
  source                 = "datos_crudos/vacunacion_rural_movil.csv"
}

resource "azurerm_storage_blob" "vacunacion_scz" {
  name                   = "vacunacion_santa_cruz.csv"
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_container.datalake-pai.name
  type                   = "Block"
  source                 = "datos_crudos/vacunacion_santa_cruz.csv"
}

# =========================================================
# 5. BASE DE DATOS Y DATA FACTORY
# =========================================================

# Servidor de Base de Datos SQL
resource "azurerm_mssql_server" "db" {
  name                         = "sql-ucb-sisger-pai-kath012026"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "adminpai"
  administrator_login_password = "S1sger2026_PAI$"
}

# Firewall (Para que Azure Data Factory y tú puedan conectarse)
resource "azurerm_mssql_firewall_rule" "rulefirewall" {
  name             = "FirewallRule1"
  server_id        = azurerm_mssql_server.db.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

# Base de Datos SQL (Capa Gold/Silver)
resource "azurerm_mssql_database" "dw-pai" {
  name         = "dw_pai"
  server_id    = azurerm_mssql_server.db.id
  collation    = "SQL_Latin1_General_CP1_CI_AS"
  license_type = "LicenseIncluded"
  max_size_gb  = 2
  sku_name     = "S0"
  enclave_type = "VBS"
 
  tags = {
    proyecto = "PAI_Vacunacion"
  }
 
  lifecycle {
    prevent_destroy = false
  }
}

# Azure Data Factory (Donde harás tu ETL visual)
resource "azurerm_data_factory" "df" {
  name                = "adf-ucb-dw-pai-kath012026"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}