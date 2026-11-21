// SwiftRust integration, Copyright (c) 2026 SwiftRust contributors.
// SPDX-License-Identifier: AGPL-3.0-only
// This file is overlaid onto the pinned libtailscale main package at build time.
package main

// #include <stdlib.h>
import "C"

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net"
	"sync"
	"time"

	"tailscale.com/envknob"
	"tailscale.com/net/socks5"
	"tailscale.com/types/logger"
)

var swiftRustProxies = struct {
	sync.Mutex
	listeners map[C.int]net.Listener
}{listeners: make(map[C.int]net.Listener)}

func swiftRustCloseProxy(sd C.int) {
	swiftRustProxies.Lock()
	l := swiftRustProxies.listeners[sd]
	delete(swiftRustProxies.listeners, sd)
	swiftRustProxies.Unlock()
	if l != nil {
		l.Close()
	}
}

//export SwiftRustTSClose
func SwiftRustTSClose(sd C.int) C.int { swiftRustCloseProxy(sd); return TsnetClose(sd) }

//export SwiftRustTSAction
func SwiftRustTSAction(sd C.int, action *C.char, output **C.char) C.int {
	*output = nil
	s := getServer(sd)
	if s == nil {
		return -1
	}
	var value any = map[string]bool{"ok": true}
	err := func() error {
		switch C.GoString(action) {
		case "configure":
			s.s.UserLogf = logger.Discard
			s.s.Logf = logger.Discard
			envknob.SetNoLogsNoSupport()
			return nil
		case "proxy":
			// Rebind only the listener after iOS suspension; established streams remain intact.
			listener, err := net.Listen("tcp4", "127.0.0.1:0")
			if err != nil {
				return err
			}
			secret := make([]byte, 24)
			if _, err := rand.Read(secret); err != nil {
				listener.Close()
				return err
			}
			password := hex.EncodeToString(secret)
			proxy := &socks5.Server{Username: "swiftrust", Password: password, Logf: logger.Discard,
				Dialer: func(ctx context.Context, network, address string) (net.Conn, error) {
					ctx, cancel := context.WithTimeout(ctx, 15*time.Second)
					defer cancel()
					return s.s.Dial(ctx, network, address)
				}}
			swiftRustCloseProxy(sd)
			swiftRustProxies.Lock()
			swiftRustProxies.listeners[sd] = listener
			swiftRustProxies.Unlock()
			go func() { _ = proxy.Serve(listener) }()
			value = map[string]string{"address": listener.Addr().String(), "username": "swiftrust", "password": password}
			return nil
		case "login", "logout":
			client, err := s.s.LocalClient()
			if err != nil {
				return err
			}
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()
			if C.GoString(action) == "login" {
				return client.StartLoginInteractive(ctx)
			}
			return client.Logout(ctx)
		default:
			return fmt.Errorf("unsupported Tailscale action")
		}
	}()
	if err != nil {
		value = map[string]string{"error": err.Error()}
	}
	data, marshalErr := json.Marshal(value)
	if marshalErr != nil {
		return -1
	}
	*output = C.CString(string(data))
	if err != nil {
		return -1
	}
	return 0
}
