import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rive/rive.dart' hide Image;
import 'login_view_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Rive controller and state machine inputs
  StateMachineController? _controller;
  SMIInput<bool>? _isChecking;
  SMIInput<bool>? _isHandsUp;
  SMIInput<double>? _lookRotation;
  SMIInput<bool>? _success;
  SMIInput<bool>? _fail;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

    _emailFocusNode.addListener(() {
      if (_emailFocusNode.hasFocus) {
        _isChecking?.value = true;
      } else {
        _isChecking?.value = false;
      }
    });

    _passwordFocusNode.addListener(() {
      if (_passwordFocusNode.hasFocus) {
        _isHandsUp?.value = true;
      } else {
        _isHandsUp?.value = false;
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _onRiveInit(Artboard artboard) {
    _controller = StateMachineController.fromArtboard(artboard, 'State Machine 1');
    if (_controller != null) {
      artboard.addController(_controller!);
      _isChecking = _controller!.findInput<bool>('Check');
      _isHandsUp = _controller!.findInput<bool>('HandsUp');
      _lookRotation = _controller!.findInput<double>('Look');
      _success = _controller!.findInput<bool>('success');
      _fail = _controller!.findInput<bool>('fail');
    }
  }

  Future<void> _handleLogin() async {
    _emailFocusNode.unfocus();
    _passwordFocusNode.unfocus();

    final viewModel = context.read<LoginViewModel>();
    final success = await viewModel.login(
      _emailController.text,
      _passwordController.text,
    );

    if (success) {
      _success?.value = true;
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/game');
        }
      });
    } else {
      _fail?.value = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(viewModel.errorMessage ?? 'Login failed')),
        );
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    final viewModel = context.read<LoginViewModel>();
    final success = await viewModel.loginWithGoogle();
    if (success) {
      _success?.value = true;
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/game');
        }
      });
    } else if (viewModel.errorMessage != null) {
      _fail?.value = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(viewModel.errorMessage!)),
        );
      }
    }
  }

  Future<void> _handleFacebookLogin() async {
    final viewModel = context.read<LoginViewModel>();
    final success = await viewModel.loginWithFacebook();
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/game');
    }
  }

  Future<void> _handlePhoneLogin() async {
    // For now, just simulate or show a dialog
    final viewModel = context.read<LoginViewModel>();
    final success = await viewModel.loginWithPhone("1234567890");
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/game');
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LoginViewModel>();
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFD6E2EA),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isSmallScreen ? double.infinity : 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  // App Logo / Decorative Image
                  Center(
                    child: Image.network(
                      'https://cdn-icons-png.flaticon.com/512/3665/3665917.png', // A bubble icon
                      height: 80,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.bubble_chart, size: 80, color: Colors.blueAccent),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Bubble Shoot",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Rive Animation Container
                  SizedBox(
                    height: isSmallScreen ? 250 : 300,
                    child: RiveAnimation.asset(
                      'assets/rive/login_bear.riv',
                      fit: BoxFit.contain,
                      onInit: _onRiveInit,
                      placeHolder: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  // Login Form
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          TextField(
                            controller: _emailController,
                            focusNode: _emailFocusNode,
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (value) {
                              _lookRotation?.value = value.length.toDouble() * 2;
                            },
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Primary Login Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: viewModel.isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6B99C3),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: viewModel.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text(
                                      'LOGIN',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text("OR", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Google Login Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: viewModel.isLoading ? null : _handleGoogleLogin,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.network(
                                    'https://www.gstatic.com/images/branding/product/2x/googleg_96dp.png',
                                    height: 20,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.account_circle, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Continue with Google',
                                    style: TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _SocialLoginButton(
                                icon: Icons.facebook,
                                color: const Color(0xFF1877F2),
                                onPressed: viewModel.isLoading ? null : _handleFacebookLogin,
                              ),
                              const SizedBox(width: 20),
                              _SocialLoginButton(
                                icon: Icons.phone_android,
                                color: Colors.green,
                                onPressed: viewModel.isLoading ? null : _handlePhoneLogin,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _SocialLoginButton({
    required this.icon,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icon, color: color, size: 30),
      ),
    );
  }
}
