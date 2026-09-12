import 'package:flutter/material.dart';

class CurvedNavItem {
  final IconData icon;
  final String label;

  const CurvedNavItem({
    required this.icon,
    required this.label,
  });
}

class CurvedBottomNavBar extends StatefulWidget {
  final List<CurvedNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final Color backgroundColor;
  final Color activeColor;
  final Color inactiveColor;

  const CurvedBottomNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    this.backgroundColor = Colors.white,
    this.activeColor = const Color(0xFF6366F1),
    this.inactiveColor = const Color(0xFF94A3B8),
  });

  @override
  State<CurvedBottomNavBar> createState() => _CurvedBottomNavBarState();
}

class _CurvedBottomNavBarState extends State<CurvedBottomNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _anim;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.selectedIndex;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _anim = CurvedAnimation(parent: _animController, curve: Curves.easeInOutCubic);
    _animController.forward(from: 1.0);
  }

  @override
  void didUpdateWidget(CurvedBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _previousIndex = oldWidget.selectedIndex;
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double barHeight = 62.0;
    final int count = widget.items.length;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final double totalWidth = constraints.maxWidth;
            final double itemWidth = totalWidth / count;

            // Interpolate current position between previous and target index
            final double animatedIndex =
                _previousIndex + (widget.selectedIndex - _previousIndex) * _anim.value;

            final double rawCenterX = (animatedIndex + 0.5) * itemWidth;
            // Clamp centerX so cutout dip and bubble stay comfortably within bar bounds
            const double minCenterX = 40.0;
            final double maxCenterX = totalWidth - 40.0;
            final double safeCenterX = rawCenterX.clamp(minCenterX, maxCenterX);

            return Container(
              height: barHeight + 20,
              margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. Curved Background Bar
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: barHeight,
                    child: PhysicalShape(
                      clipper: CurvedNavClipper(centerX: safeCenterX),
                      color: widget.backgroundColor,
                      elevation: 10,
                      shadowColor: Colors.black.withAlpha(90),
                      child: Container(),
                    ),
                  ),

                  // 2. Floating Active Icon Circle Bubble
                  Positioned(
                    left: safeCenterX - 25.0,
                    top: 2,
                    child: GestureDetector(
                      onTap: () => widget.onTap(widget.selectedIndex),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: widget.backgroundColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: widget.activeColor.withAlpha(120),
                              blurRadius: 12,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            widget.items[widget.selectedIndex].icon,
                            color: widget.activeColor,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 3. Tab Labels and Unselected Icons
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: barHeight,
                    child: Row(
                      children: List.generate(count, (index) {
                        final isSelected = index == widget.selectedIndex;
                        final item = widget.items[index];

                        return Expanded(
                          child: InkWell(
                            onTap: () => widget.onTap(index),
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (!isSelected)
                                  Icon(
                                    item.icon,
                                    color: widget.inactiveColor,
                                    size: 22,
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isSelected
                                        ? widget.activeColor
                                        : widget.inactiveColor,
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class CurvedNavClipper extends CustomClipper<Path> {
  final double centerX;

  CurvedNavClipper({required this.centerX});

  @override
  Path getClip(Size size) {
    final path = Path();
    const double radius = 28.0;
    const double shoulder = 12.0;

    final double safeCenterX = centerX.clamp(radius + shoulder + 4, size.width - (radius + shoulder + 4));

    path.moveTo(0, 20);
    path.quadraticBezierTo(0, 0, 20, 0);

    // Left shoulder before cutout dip
    final double leftStart = safeCenterX - radius - shoulder;
    path.lineTo(leftStart, 0);

    // Cubic dip into cutout
    path.cubicTo(
      safeCenterX - radius + 4, 0,
      safeCenterX - radius * 0.7, 24,
      safeCenterX, 24,
    );

    // Cubic rise out of cutout
    path.cubicTo(
      safeCenterX + radius * 0.7, 24,
      safeCenterX + radius - 4, 0,
      safeCenterX + radius + shoulder, 0,
    );

    // Top right edge and corner
    path.lineTo(size.width - 20, 0);
    path.quadraticBezierTo(size.width, 0, size.width, 20);

    // Right edge and bottom right corner
    path.lineTo(size.width, size.height - 20);
    path.quadraticBezierTo(size.width, size.height, size.width - 20, size.height);

    // Bottom edge and bottom left corner
    path.lineTo(20, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - 20);

    // Close path
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CurvedNavClipper oldDelegate) {
    return oldDelegate.centerX != centerX;
  }
}

