import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:pointycastle/export.dart';

class ChatKeyPair {
  final String publicKeyPem;
  final String privateKeyPem;

  const ChatKeyPair({required this.publicKeyPem, required this.privateKeyPem});
}

class ChatCryptoException implements Exception {
  final String message;
  ChatCryptoException(this.message);
  @override
  String toString() => 'ChatCryptoException: $message';
}

class ChatCrypto {
  ChatKeyPair generateKeyPair({int bitLength = 2048}) {
    final keyParams = RSAKeyGeneratorParameters(
      BigInt.parse('65537'),
      bitLength,
      64,
    );

    final secureRandom = _secureRandom();
    final generator = RSAKeyGenerator()
      ..init(ParametersWithRandom(keyParams, secureRandom));

    final pair = generator.generateKeyPair();
    final publicKey = pair.publicKey as RSAPublicKey;
    final privateKey = pair.privateKey as RSAPrivateKey;

    return ChatKeyPair(
      publicKeyPem: _encodePublicKeyToPem(publicKey),
      privateKeyPem: _encodePrivateKeyToPem(privateKey),
    );
  }

  String encrypt({required String plaintext, required String publicKeyPem}) {
    if (publicKeyPem.isEmpty) {
      throw ChatCryptoException('Public key is empty');
    }
    final publicKey = _parsePublicKey(publicKeyPem);
    final engine = OAEPEncoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

    final input = Uint8List.fromList(utf8.encode(plaintext));
    final output = _processInBlocks(engine, input);
    return base64Encode(output);
  }

  String decrypt({
    required String ciphertextBase64,
    required String privateKeyPem,
  }) {
    if (ciphertextBase64.isEmpty) {
      throw ChatCryptoException('Ciphertext is empty');
    }
    if (privateKeyPem.isEmpty) {
      throw ChatCryptoException('Private key is empty');
    }
    final privateKey = _parsePrivateKey(privateKeyPem);
    final engine = OAEPEncoding(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));

    final input = base64Decode(ciphertextBase64);
    final output = _processInBlocks(engine, input);
    return utf8.decode(output);
  }

  Uint8List _processInBlocks(AsymmetricBlockCipher engine, Uint8List input) {
    final inputBlockSize = engine.inputBlockSize;
    final output = BytesBuilder(copy: false);

    for (var offset = 0; offset < input.length; offset += inputBlockSize) {
      final end = min(offset + inputBlockSize, input.length);
      final chunk = Uint8List.sublistView(input, offset, end);
      output.add(engine.process(chunk));
    }

    return output.toBytes();
  }

  RSAPublicKey _parsePublicKey(String pem) {
    try {
      final bytes = _decodePem(pem);
      final parser = ASN1Parser(bytes);
      final sequence = parser.nextObject() as ASN1Sequence;
      final elements = sequence.elements;
      if (elements.length < 2) {
        throw ChatCryptoException('Invalid public key ASN1 structure: expected at least 2 elements');
      }

      final publicKeyBitString = elements[1] as ASN1BitString;
      final contentBytes = publicKeyBitString.contentBytes();

      final publicKeyParser = ASN1Parser(contentBytes);
      final publicKeySeq = publicKeyParser.nextObject() as ASN1Sequence;
      final pkElements = publicKeySeq.elements;
      if (pkElements.length < 2) {
        throw ChatCryptoException('Invalid public key inner ASN1 structure: expected at least 2 elements');
      }

      final modulus = (pkElements[0] as ASN1Integer).valueAsBigInteger;
      final exponent = (pkElements[1] as ASN1Integer).valueAsBigInteger;

      return RSAPublicKey(modulus, exponent);
    } on ChatCryptoException {
      rethrow;
    } catch (e) {
      throw ChatCryptoException('Failed to parse public key: $e');
    }
  }

  RSAPrivateKey _parsePrivateKey(String pem) {
    try {
      final bytes = _decodePem(pem);
      final parser = ASN1Parser(bytes);
      final sequence = parser.nextObject() as ASN1Sequence;
      final topElements = sequence.elements;
      if (topElements.length < 3) {
        throw ChatCryptoException('Invalid private key ASN1 structure: expected at least 3 elements');
      }

      final privateKeyOctet = topElements[2] as ASN1OctetString;
      final octets = privateKeyOctet.octets;

      final privateKeyParser = ASN1Parser(octets);
      final privateKeySeq = privateKeyParser.nextObject() as ASN1Sequence;
      final pkElements = privateKeySeq.elements;
      if (pkElements.length < 6) {
        throw ChatCryptoException('Invalid private key inner ASN1 structure: expected at least 6 elements');
      }

      final modulus = (pkElements[1] as ASN1Integer).valueAsBigInteger;
      final privateExponent = (pkElements[3] as ASN1Integer).valueAsBigInteger;
      final p = (pkElements[4] as ASN1Integer).valueAsBigInteger;
      final q = (pkElements[5] as ASN1Integer).valueAsBigInteger;

      return RSAPrivateKey(modulus, privateExponent, p, q);
    } on ChatCryptoException {
      rethrow;
    } catch (e) {
      throw ChatCryptoException('Failed to parse private key: $e');
    }
  }

  String _encodePublicKeyToPem(RSAPublicKey publicKey) {
    final modulus = publicKey.modulus ??  (throw ChatCryptoException('Public key modulus is null'));
    final exponent = publicKey.exponent ?? (throw ChatCryptoException('Public key exponent is null'));

    final algorithmSeq = ASN1Sequence()
      ..add(ASN1ObjectIdentifier.fromName('rsaEncryption'))
      ..add(ASN1Null());

    final publicKeySeq = ASN1Sequence()
      ..add(ASN1Integer(modulus))
      ..add(ASN1Integer(exponent));

    final publicKeyBitString =
        ASN1BitString(publicKeySeq.encodedBytes);

    final topLevelSeq = ASN1Sequence()
      ..add(algorithmSeq)
      ..add(publicKeyBitString);

    return _encodePem('PUBLIC KEY', topLevelSeq.encodedBytes);
  }

  String _encodePrivateKeyToPem(RSAPrivateKey privateKey) {
    final modulus = privateKey.modulus ?? (throw ChatCryptoException('Private key modulus is null'));
    final privExp = privateKey.privateExponent ?? (throw ChatCryptoException('Private key exponent is null'));
    final p = privateKey.p ?? (throw ChatCryptoException('Private key p is null'));
    final q = privateKey.q ?? (throw ChatCryptoException('Private key q is null'));

    final version = ASN1Integer(BigInt.zero);
    final modulusAsn = ASN1Integer(modulus);
    final publicExponent = ASN1Integer(BigInt.parse('65537'));
    final privateExponent = ASN1Integer(privExp);
    final pAsn = ASN1Integer(p);
    final qAsn = ASN1Integer(q);
    final dP = ASN1Integer(privExp % (p - BigInt.one));
    final dQ = ASN1Integer(privExp % (q - BigInt.one));
    final qInv = ASN1Integer(_modInverse(q, p));

    final privateKeySeq = ASN1Sequence()
      ..add(version)
      ..add(modulusAsn)
      ..add(publicExponent)
      ..add(privateExponent)
      ..add(pAsn)
      ..add(qAsn)
      ..add(dP)
      ..add(dQ)
      ..add(qInv);

    final algorithmSeq = ASN1Sequence()
      ..add(ASN1ObjectIdentifier.fromName('rsaEncryption'))
      ..add(ASN1Null());

    final privateKeyInfoSeq = ASN1Sequence()
      ..add(ASN1Integer(BigInt.zero))
      ..add(algorithmSeq)
      ..add(ASN1OctetString(privateKeySeq.encodedBytes));

    return _encodePem('PRIVATE KEY', privateKeyInfoSeq.encodedBytes);
  }

  Uint8List _decodePem(String pem) {
    final lines = pem
        .replaceAll('\r', '')
        .split('\n')
        .where((line) =>
            line.isNotEmpty &&
            !line.startsWith('-----BEGIN') &&
            !line.startsWith('-----END'))
        .toList();
    return base64Decode(lines.join(''));
  }

  String _encodePem(String label, Uint8List bytes) {
    final b64 = base64Encode(bytes);
    final chunks = <String>[];
    for (var i = 0; i < b64.length; i += 64) {
      chunks.add(b64.substring(i, min(i + 64, b64.length)));
    }
    return '-----BEGIN $label-----\n${chunks.join('\n')}\n-----END $label-----';
  }

  SecureRandom _secureRandom() {
    final secureRandom = FortunaRandom();
    final seed = Uint8List(32);
    final random = Random.secure();
    for (var i = 0; i < seed.length; i++) {
      seed[i] = random.nextInt(256);
    }
    secureRandom.seed(KeyParameter(seed));
    return secureRandom;
  }

  BigInt _modInverse(BigInt a, BigInt m) {
    var t = BigInt.zero;
    var newT = BigInt.one;
    var r = m;
    var newR = a % m;

    while (newR != BigInt.zero) {
      final quotient = r ~/ newR;
      final tempT = t - quotient * newT;
      t = newT;
      newT = tempT;
      final tempR = r - quotient * newR;
      r = newR;
      newR = tempR;
    }

    if (r > BigInt.one) {
      throw ChatCryptoException('No modular inverse — invalid key parameters');
    }
    if (t.isNegative) {
      t += m;
    }
    return t;
  }
}
