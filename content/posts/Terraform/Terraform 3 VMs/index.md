---
title: Автоматическая установка нескольких виртуальных машин в Proxmox 9.0.3 с помощью Terraform в Docker
published: 2025-09-22
pinned: false
description: Пошаговое руководство по использованию Terraform для автоматического создания виртуальных машин в кластере Proxmox VE. Примеры кода, советы по настройке, улучшение DevOps-процессов.
tags:
  - Terraform
  - Proxmox
  - DevOps
  - Автоматизация
  - IaC
slug: /terraform-proxmox-3vm-automation/
categories: Terraform
licenseName: CC BY 4.0
author: Stilicho2011
draft: false
series:
  - Автоматизация в Proxmox
youtube_id: bL8qoBs09LE
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: ./featured.png
summary: Пошаговое руководство по автоматической установке нескольких виртуальных машин в Proxmox 9.0.3 с использованием Terraform в Docker. Рассмотрены настройка окружения, создание конфигураций Terraform и автоматизация развертывания VM для ускорения работы с Proxmox.
---


<iframe width="100%" height="468" src="https://www.youtube.com/embed/bL8qoBs09LE?si=BJjNYwQ8dQQ_UTHK" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

Ниже приведен файл, который я использовал в ролике, посвященный установке и развертыванию сразу трех виртуальных машин с помощью Terraform

```yaml
variable vm_configs {
  type = map(object({
      vm_id = number
      name = string
      cores = number
      memory = number
      vm_state = string 
  }))
  default = {
      "youtube-1" = { vm_id = 357, name = "youtube-1", cores = 1, memory = 2048, vm_state = "stopped"}
      "youtube-2" = { vm_id = 358, name = "youtube-2", cores = 1, memory = 4096, vm_state = "stopped"}   
      "youtube-3" = { vm_id = 359, name = "youtube-3", cores = 1, memory = 2048, vm_state = "running"}
  }
}

resource "proxmox_vm_qemu" "youtubetestvms" {
  for_each = var.vm_configs
  vmid        = each.value.vm_id
  name        = each.value.name
  target_node = "belisarius"
  clone       = "ubuntutemplate"
  full_clone  = true
  bios        = "ovmf"
  agent       = 1 
  scsihw      = "virtio-scsi-single"
  os_type     = "ubuntu"
  cpu_type    = "x86-64-v2-AES"
  cores       = each.value.cores
  sockets     = 1
  memory      = each.value.memory 

  vm_state = each.value.vm_state


  disks {
    scsi {
      scsi0 {
        disk {
          size    = "32G"
          storage = "local"
          format  = "qcow2"
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }
}
```
