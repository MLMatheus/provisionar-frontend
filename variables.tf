variable "zone_id" {
  default = "Z03551401LMEBZ08T1OPU"
  type    = string
}

variable "region" {
  type        = string
  description = "Região na AWS onde serão provisionados os recursos"
  default     = "us-east-1"
}

variable "s3_backend" {
  type        = string
  description = "Nome do bucket onde serão salvos os arquivos de estado do Terraform"
}

variable "key" {
  type        = string
  description = "Caminho relativo e nome do arquivo onde será salvo o arquivo de estado do Terraform dentro do bucket"
}

variable "s3_front" {
  type        = string
  description = "Nome do bucket para os arquivos do frontend"
}

variable "domain_name" {
  type        = string
  description = "Nome do domínio principal do seu site"
}

variable "subdomain" {
  type        = string
  description = "Sub domínio para seu site. Deixar vazio para usar o domínio raíz"
  default = ""
}
