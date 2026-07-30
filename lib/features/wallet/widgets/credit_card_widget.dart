import 'package:flutter/material.dart';

class CreditCardWidget extends StatelessWidget {
  final String bankName;
  final String cardNumber;
  final String availableLimit;
  final Color cardColor;

  const CreditCardWidget({
    super.key,
    required this.bankName,
    required this.cardNumber,
    required this.availableLimit,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                bankName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Icon(
                Icons.credit_card,
                color: Colors.white,
              ),
            ],
          ),

          const SizedBox(height: 30),

          Text(
            "**** **** **** $cardNumber",
            style: const TextStyle(
              color: Colors.white,
              letterSpacing: 2,
              fontSize: 18,
            ),
          ),

          const SizedBox(height: 30),

          const Text(
            "Available Limit",
            style: TextStyle(
              color: Colors.white70,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            availableLimit,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        ],
      ),
    );
  }
}