import socket
import threading
import sys

def forward(src, dst, direction):
    try:
        while True:
            data = src.recv(32768)
            if not data:
                break
            dst.sendall(data)
    except Exception:
        pass
    finally:
        try:
            src.close()
        except:
            pass
        try:
            dst.close()
        except:
            pass

def handle_client(client_socket):
    target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        target_socket.connect(('127.0.0.1', 27015))
    except Exception as e:
        print(f"[Proxy] Failed to connect to 27015: {e}", flush=True)
        client_socket.close()
        return

    t1 = threading.Thread(target=forward, args=(client_socket, target_socket, "WSL->Win"), daemon=True)
    t2 = threading.Thread(target=forward, args=(target_socket, client_socket, "Win->WSL"), daemon=True)
    t1.start()
    t2.start()

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', 27016))
    server.listen(50)
    print("[Proxy] Listening on 0.0.0.0:27016 for WSL usbmuxd requests...", flush=True)
    while True:
        client, addr = server.accept()
        threading.Thread(target=handle_client, args=(client,), daemon=True).start()

if __name__ == '__main__':
    main()
