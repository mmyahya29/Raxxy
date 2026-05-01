              _buildCard([
                _field(makeController,    'Make',            'e.g. Toyota',  isRequired: true,
                    keyboardType: TextInputType.text,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Make is required' : null,
                ),
                _field(modelController,   'Model',           'e.g. Corolla', isRequired: true,
                    keyboardType: TextInputType.text,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Model is required' : null,
                ),
                _field(yearController,    'Year',            'e.g. 2021',    isRequired: true,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final y = int.tryParse(v);
                      if (y == null || y < 1900 || y > DateTime.now().year + 2) {
                        return 'Enter a valid year';
                      }
                      return null;
                    }),
                _field(mileageController, 'Current Mileage (km)', 'e.g. 45000', isRequired: true,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Enter a number';
                      return null;
                    }),
              ]),