output "master_ip" {
  value = aws_instance.master.public_ip
}

output "worker_ip" {
  value = [for instance in aws_instance.worker : instance.public_ip]
}