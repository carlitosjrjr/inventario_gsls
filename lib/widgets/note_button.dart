import 'package:flutter/material.dart';

class NoteButton extends StatelessWidget {
  const NoteButton({
    super.key,
    required this.child,
    this.onPressed,
    this.isOutlined = false,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool isOutlined;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            offset: const Offset(2, 2),
            color: isOutlined
                ? Colors.black
                : Colors.black,
          ),
        ],
        borderRadius: BorderRadius.circular(8),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
          isOutlined ? Colors.white : const Color.fromRGBO(59, 122, 201, 1),
          foregroundColor:
          isOutlined ? Colors.black : Colors.white,
          disabledBackgroundColor: Colors.grey,
          disabledForegroundColor: Colors.black,
          side: BorderSide(
              color: isOutlined
                  ? Colors.black
                  : Colors.black),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: child,
      ),
    );
  }
}
