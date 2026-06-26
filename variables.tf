variable "instance_type" {
    default = "t3.micro"
  
}

variable "name" {
    default = "tp-video"
  
}



/*variable "instance_type" {
    type = list(any)
    default = ["t3.micro", "t3.medium", "t3.large"]
  
}

variable "name" {
    type = map(any)
    default = {
        dev = "ec2-dev"
        prod = "ec2-prod"
        staging = "ec2-staging"

    }
  
}*/ #c'est pour montrer les differents types de variables


variable "sg_ports" {
    type = list
    default = [22, 80, 443]
  #c'est la déclaration de variables des groupes de securité
}


