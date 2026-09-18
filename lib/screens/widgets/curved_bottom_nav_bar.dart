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
    final double barHeight = 60.0;
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

            const double radius = 22.0;
            const double shoulder = 10.0;
            const double cornerRadius = 18.0;
            final double minAllowed = cornerRadius + radius + shoulder + 2.0; // 52.0
            final double maxAllowed = totalWidth - minAllowed;
            final double safeCenterX = rawCenterX.clamp(minAllowed, maxAllowed);

            return SafeArea(
              top: false,
              bottom: true,
              child: Container(
                height: barHeight + 16,
                margin: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Curved Background Bar Card
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: barHeight,
                      child: PhysicalShape(
                        clipper: CurvedNavClipper(centerX: safeCenterX),
                        color: widget.backgroundColor,
                        elevation: 8,
                        shadowColor: Colors.black.withAlpha(70),
                        child: Container(),
                      ),
                    ),

                    // 2. Floating Active Icon Circle Bubble
                    Positioned(
                      left: safeCenterX - 23.0,
                      top: 4,
                      child: GestureDetector(
                        onTap: () => widget.onTap(widget.selectedIndex),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: widget.backgroundColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: widget.activeColor.withAlpha(100),
                                blurRadius: 8,
                                spreadRadius: 0,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              widget.items[widget.selectedIndex].icon,
                              color: widget.activeColor,
                              size: 24,
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
                                      size: 20,
                                    ),
                                  const SizedBox(height: 3),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        item.label,
                                        maxLines: 1,
                                        style: TextStyle(
                                          color: isSelected
                                              ? widget.activeColor
                                              : widget.inactiveColor,
                                          fontSize: 10.5,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
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
    const double radius = 22.0;
    const double shoulder = 10.0;
    const double cornerRadius = 18.0;

    final double minAllowed = cornerRadius + radius + shoulder + 2.0; // 52.0
    final double maxAllowed = size.width - minAllowed;
    final double safeCenterX = centerX.clamp(minAllowed, maxAllowed);

    path.moveTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);

    // Left shoulder before cutout dip
    final double leftStart = safeCenterX - radius - shoulder;
    path.lineTo(leftStart, 0);

    // Smooth cubic dip into cutout
    path.cubicTo(
      safeCenterX - radius + 2, 0,
      safeCenterX - radius * 0.65, 20,
      safeCenterX, 20,
    );

    // Smooth cubic rise out of cutout
    path.cubicTo(
      safeCenterX + radius * 0.65, 20,
      safeCenterX + radius - 2, 0,
      safeCenterX + radius + shoulder, 0,
    );

    // Right shoulder to top-right corner
    path.lineTo(size.width - cornerRadius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, cornerRadius);

    // Right edge and bottom-right corner
    path.lineTo(size.width, size.height - cornerRadius);
    path.quadraticBezierTo(size.width, size.height, size.width - cornerRadius, size.height);

    // Bottom edge and bottom-left corner
    path.lineTo(cornerRadius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - cornerRadius);

    // Close path
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CurvedNavClipper oldDelegate) {
    return oldDelegate.centerX != centerX;
  }
}
