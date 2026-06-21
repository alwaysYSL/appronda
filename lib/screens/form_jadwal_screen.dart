import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:appronda/models/jadwal_ronda.dart';
import 'package:appronda/services/firestore_service.dart';

class FormJadwalScreen extends StatefulWidget {
  final JadwalRonda? jadwal;

  const FormJadwalScreen({super.key, this.jadwal});

  @override
  State<FormJadwalScreen> createState() => _FormJadwalScreenState();
}

class _FormJadwalScreenState extends State<FormJadwalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();

  late String _selectedHari;
  late DateTime _selectedTanggal;
  final _areaController = TextEditingController();
  final List<TextEditingController> _petugasControllers = [];

  bool _isLoading = false;
  List<String> _availableEmails = [];
  bool _isLoadingEmails = true;

  final List<String> _daftarHari = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu'
  ];

  @override
  void initState() {
    super.initState();
    _loadWargaEmails();
    
    // Inisialisasi data jika mode edit
    if (widget.jadwal != null) {
      _selectedHari = _daftarHari.contains(widget.jadwal!.hari)
          ? widget.jadwal!.hari
          : 'Senin';
      _selectedTanggal = widget.jadwal!.tanggal;
      _areaController.text = widget.jadwal!.area;
      
      for (var nama in widget.jadwal!.petugas) {
        _petugasControllers.add(TextEditingController(text: nama));
      }
    } else {
      // Inisialisasi data default untuk tambah baru
      _selectedHari = 'Senin';
      _selectedTanggal = DateTime.now();
      _petugasControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _areaController.dispose();
    for (var controller in _petugasControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadWargaEmails() async {
    try {
      List<String> emails = await _firestoreService.getAllUserEmails();
      setState(() {
        _availableEmails = emails;
        _isLoadingEmails = false;
      });
    } catch (_) {
      setState(() {
        _isLoadingEmails = false;
      });
    }
  }

  void _tambahPetugasField() {
    setState(() {
      _petugasControllers.add(TextEditingController());
    });
  }

  void _hapusPetugasField(int index) {
    if (_petugasControllers.length > 1) {
      setState(() {
        _petugasControllers[index].dispose();
        _petugasControllers.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimal harus ada 1 petugas ronda'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _pilihTanggal(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedTanggal,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.cyanAccent,
              onPrimary: Colors.black,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTanggal) {
      setState(() {
        _selectedTanggal = picked;
      });
    }
  }

  void _simpanJadwal() async {
    if (!_formKey.currentState!.validate()) return;

    // Ambil daftar nama petugas dan bersihkan whitespace
    List<String> petugasList = _petugasControllers
        .map((c) => c.text.trim())
        .where((nama) => nama.isNotEmpty)
        .toList();

    if (petugasList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan isi minimal 1 nama petugas dengan benar'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.jadwal != null) {
        // Mode Edit
        await _firestoreService.updateJadwal(
          widget.jadwal!.id,
          _selectedHari,
          _selectedTanggal,
          _areaController.text.trim(),
          petugasList,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Jadwal ronda berhasil diperbarui!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Mode Tambah
        await _firestoreService.addJadwal(
          _selectedHari,
          _selectedTanggal,
          _areaController.text.trim(),
          petugasList,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Jadwal ronda baru berhasil ditambahkan!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.jadwal != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B), // Slate 800
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditMode ? 'Edit Jadwal Ronda' : 'Tambah Jadwal Ronda',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 2,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Form Container Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B), // Slate 800
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blueGrey[800]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dropdown Hari
                      const Text(
                        'Hari Ronda',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedHari,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.calendar_today_rounded, color: Colors.cyanAccent),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.blueGrey[700]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
                          ),
                        ),
                        items: _daftarHari
                            .map((hari) => DropdownMenuItem(
                                  value: hari,
                                  child: Text(hari),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedHari = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 20),

                      // Tanggal Ronda
                      const Text(
                        'Tanggal Ronda',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _pilihTanggal(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blueGrey[700]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.date_range_rounded,
                                  color: Colors.cyanAccent),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat('dd MMMM yyyy')
                                    .format(_selectedTanggal),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 16),
                              ),
                              const Spacer(),
                              const Icon(Icons.arrow_drop_down_rounded,
                                  color: Colors.blueGrey),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Input Area Pos
                      const Text(
                        'Area / Pos Ronda',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _areaController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Contoh: Pos Ronda RT 01',
                          hintStyle: TextStyle(color: Colors.blueGrey[500]),
                          prefixIcon: const Icon(Icons.map_rounded, color: Colors.cyanAccent),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.blueGrey[700]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.redAccent),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Area ronda tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Dynamic Petugas List Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B), // Slate 800
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blueGrey[800]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Petugas Ronda',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _tambahPetugasField,
                            icon: const Icon(Icons.add_circle_outline,
                                color: Colors.cyanAccent, size: 20),
                            label: const Text(
                              'Tambah',
                              style: TextStyle(color: Colors.cyanAccent),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _petugasControllers.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return Row(
                            children: [
                              Expanded(
                                child: _isLoadingEmails
                                    ? const Center(
                                        child: SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.cyanAccent,
                                          ),
                                        ),
                                      )
                                    : _availableEmails.isEmpty
                                        ? TextFormField(
                                            controller: _petugasControllers[index],
                                            style: const TextStyle(color: Colors.white),
                                            decoration: InputDecoration(
                                              hintText: 'Email Petugas ${index + 1}',
                                              hintStyle: TextStyle(color: Colors.blueGrey[500]),
                                              prefixIcon: const Icon(Icons.person_outline, color: Colors.blueGrey),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide(color: Colors.blueGrey[700]!),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: const BorderSide(color: Colors.redAccent),
                                              ),
                                              focusedErrorBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                                              ),
                                            ),
                                            validator: (value) {
                                              if (value == null || value.trim().isEmpty) {
                                                return 'Email petugas tidak boleh kosong';
                                              }
                                              return null;
                                            },
                                          )
                                        : DropdownButtonFormField<String>(
                                            initialValue: _petugasControllers[index].text.isNotEmpty && _availableEmails.contains(_petugasControllers[index].text)
                                                ? _petugasControllers[index].text
                                                : null,
                                            dropdownColor: const Color(0xFF1E293B),
                                            style: const TextStyle(color: Colors.white),
                                            decoration: InputDecoration(
                                              hintText: 'Pilih Email Petugas ${index + 1}',
                                              hintStyle: TextStyle(color: Colors.blueGrey[500]),
                                              prefixIcon: const Icon(Icons.person_outline, color: Colors.blueGrey),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide(color: Colors.blueGrey[700]!),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: const BorderSide(color: Colors.redAccent),
                                              ),
                                              focusedErrorBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                                              ),
                                            ),
                                            items: _availableEmails.map((email) {
                                              return DropdownMenuItem(
                                                value: email,
                                                child: Text(
                                                  email,
                                                  style: const TextStyle(fontSize: 13),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (value) {
                                              if (value != null) {
                                                setState(() {
                                                  _petugasControllers[index].text = value;
                                                });
                                              }
                                            },
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
                                                return 'Silakan pilih petugas';
                                              }
                                              return null;
                                            },
                                          ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: Colors.redAccent),
                                onPressed: () => _hapusPetugasField(index),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Save/Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _simpanJadwal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent[400],
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                    shadowColor: Colors.cyanAccent.withValues(alpha: 0.3),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          isEditMode ? 'PERBARUI JADWAL' : 'SIMPAN JADWAL',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
