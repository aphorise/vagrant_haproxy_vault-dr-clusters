# // seal stanza eg: seal "awkskms" { ...
seal "pkcs11" {
	lib		= "/usr/local/lib/softhsm/libsofthsm2.so"
	slot		= "9999999999"
	pin		= "1234"
	key_label	= "hsm:v1:vault"
	hmac_key_label	= "hsm:v1:vault-hmac"
	generate_key	= "true"
	#mechanism 	= "0x1087"  # // may be needed with some hw
	#hmac_mechanism = "0x0251"  # // may be needed with some hw
}
