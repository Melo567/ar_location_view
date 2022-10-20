# ar_location_view

Augmented reality for geo location for flutter.
Inspired ![HDAugmentedReality](https://github.com/DanijelHuis/HDAugmentedReality)


# Demo

![ArLocationView](design/demo.gif)


## Description

ArLocationView is designed to used in areas with large concentration of static POIs.
Where primary goal is the visibility of all POIs.

Remark: Altitudes of POIs are disregarded


### Features
* Automatic vertical stacking of annotations views
* Tracks user movement and updates visible annotations
* Fully customisable annotation view
* Supports all rotations


### Basic usage
Look at the example

Create class extend ArAnnotation

```dart
class Annotation extends ArAnnotation {
  final AnnotationType type;
  
  Annotation({required super.uid, required super.position, required this.type});
}
```

Create a widget for Annotation view for example
```dart

class AnnotationView extends StatelessWidget {
  const AnnotationView({
    Key? key,
    required this.annotation,
  }) : super(key: key);

  final Annotation annotation;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              child: typeFactory(annotation.type),
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
                  Text(
                    annotation.type.toString().substring(15),
                    maxLines: 1,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${annotation.distanceFromUser.toInt()} m',
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget typeFactory(AnnotationType type) {
    IconData iconData = Icons.ac_unit_outlined;
    Color color = Colors.teal;
    switch (type) {
      case AnnotationType.pharmacy:
        iconData = Icons.local_pharmacy_outlined;
        color = Colors.red;
        break;
      case AnnotationType.hotel:
        iconData = Icons.hotel_outlined;
        color = Colors.green;
        break;
      case AnnotationType.library:
        iconData = Icons.library_add_outlined;
        color = Colors.blue;
        break;
    }
    return Icon(
      iconData,
      size: 40,
      color: color,
    );
  }
}
```

## License

ArLocationView is released under the MIT license.