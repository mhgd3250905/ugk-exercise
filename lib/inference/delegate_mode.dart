enum DelegateMode { cpu, nnapi, gpu }

DelegateMode nextDelegateMode(DelegateMode mode) {
  const values = DelegateMode.values;
  return values[(values.indexOf(mode) + 1) % values.length];
}
