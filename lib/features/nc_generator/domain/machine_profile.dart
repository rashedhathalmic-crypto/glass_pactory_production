/// Controller conventions and safe machine defaults for the SKG1625.
class MachineProfile {
  const MachineProfile({
    this.name = 'SKG1625',
    this.decimalPlaces = 4,
    this.defaultWorkOffset = 'G58',
    this.parkX = -400,
    this.parkY = 300,
  });

  final String name;
  final int decimalPlaces;
  final String defaultWorkOffset;
  final double parkX, parkY;

  static const skg1625 = MachineProfile();
}
