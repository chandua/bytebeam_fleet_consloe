import 'package:flutter/material.dart';

class VehicleDetailScreen extends StatefulWidget {
  const VehicleDetailScreen({super.key, required this.vehicleId});

  final String vehicleId;


  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
