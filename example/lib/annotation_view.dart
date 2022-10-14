import 'package:flutter/material.dart';

import 'annotations.dart';

class ImmoAnnotationView extends StatelessWidget {
  const ImmoAnnotationView({
    Key? key,
    required this.onClick,
    required this.annotation,
  }) : super(key: key);

  final VoidCallback onClick;
  final ImmoAnnotation annotation;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClick,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(5),
                    bottomLeft: Radius.circular(5),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '100 00 €',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Text(
                              annotation.action,
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                    const Text(
                      'Libel',
                      style: TextStyle(
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${annotation.distanceFromUser.toInt()} m',
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
