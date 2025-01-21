output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_spot_instance_request.android_emulator.spot_instance_id
}

output "public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_spot_instance_request.android_emulator.public_ip
}

output "spot_request_id" {
  description = "Spot request ID"
  value       = aws_spot_instance_request.android_emulator.id
}
