import 'package:flutter/material.dart';

import '../../data/post_location.dart';

class PostLocationLabel extends StatelessWidget {
  const PostLocationLabel({super.key, required this.location});
  final PostLocation location;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.place_outlined, size: 15),
      const SizedBox(width: 3),
      Flexible(child: Text(location.name, maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall)),
    ]),
  );
}
