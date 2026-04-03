# Outputs we need from terraform

output "Bastion-server_ip" {
  value = "${aws_instance.Bastion-server.public_ip}"
}

output "Web-VM_ip" {
  value = "${aws_instance.Web-VM.public_ip}"
  
}

output "App-VM_ip" {
  value = "${aws_instance.App-VM.private_ip}"
}

output "DB-VM_ip" {
  value = "${aws_instance.DB-VM.private_ip}"
}