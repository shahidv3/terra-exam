<!-- TABLE OF CONTENTS -->
## Table of Contents

* [About the Project](#about-the-project)
  * [Built With](#built-with)
* [Getting Started](#getting-started)
  * [Prerequisites](#prerequisites)
  * [Installation](#installation)

<!-- High level architecture diagram -->
![Alt text](terra1.png?raw=true "Title")

<!-- ABOUT THE PROJECT -->
## About The Project

This project shows how to create all the resources to deploy webserver in an auto scaling group with elb using Terraform using `IAC` concepts (Infraestructure As A Code) on AWS platform 

<!-- TECHNOLOGIES -->
### Built With
* [Terraform](https://www.terraform.io)

<!-- GETTING STARTED -->
## Getting Started

To apply terraform templates, `Terraform` must first be installed on your machine. 

### Prerequisites

Before running terraform templates, download [terraform client](https://www.terraform.io/downloads.html) and [install](https://learn.hashicorp.com/terraform/getting-started/install.html) acconding to your `OS`.

### Installation

1. Clone the repo:
```sh
git clone https://github.com/shahidv3/terra-exam.git
```
2. Init terraform provider:
```sh
terraform init
```
3. Verify all changes to be applied:
```sh
terraform plan
```
4. Check all changes and apply the template:
```sh
terraform apply
```
