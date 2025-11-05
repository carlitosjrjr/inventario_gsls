import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';

class Base64ImageWidget extends StatelessWidget {
  final String? base64String;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? errorWidget;

  const Base64ImageWidget({
    Key? key,
    this.base64String,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (base64String == null || base64String!.isEmpty) {
      return _buildErrorWidget();
    }

    try {
      // Verificar si la cadena tiene el prefijo data:image
      String base64Data;
      if (base64String!.startsWith('data:image')) {
        // Extraer solo la parte Base64
        base64Data = base64String!.split(',')[1];
      } else {
        base64Data = base64String!;
      }

      Uint8List bytes = base64Decode(base64Data);

      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget();
        },
      );
    } catch (e) {
      return _buildErrorWidget();
    }
  }

  Widget _buildErrorWidget() {
    return errorWidget ??
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.broken_image,
            color: Colors.grey.shade600,
            size: (width != null && height != null)
                ? (width! < height! ? width! * 0.5 : height! * 0.5)
                : 30,
          ),
        );
  }
}

// Función de utilidad para verificar si una cadena es Base64
class Base64Utils {
  static bool isBase64(String? str) {
    if (str == null || str.isEmpty) return false;

    try {
      String base64Data;
      if (str.startsWith('data:image')) {
        base64Data = str.split(',')[1];
      } else {
        base64Data = str;
      }

      base64Decode(base64Data);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Uint8List? decodeBase64(String? str) {
    if (!isBase64(str)) return null;

    try {
      String base64Data;
      if (str!.startsWith('data:image')) {
        base64Data = str.split(',')[1];
      } else {
        base64Data = str;
      }

      return base64Decode(base64Data);
    } catch (e) {
      return null;
    }
  }
}