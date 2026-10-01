#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>

#define SOCKET_PATH "/tmp/agent_touchbar.sock"

int main(int argc, char *argv[]) {
    const char *msg = (argc > 1) ? argv[1] : "🛡️ 待审批请求";
    
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) {
        perror("socket");
        return 1;
    }
    
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCKET_PATH, sizeof(addr.sun_path) - 1);
    
    if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        fprintf(stderr, "Error: agent-touchbar daemon is not running.\n");
        fprintf(stderr, "Start it first with: ./agent-touchbar-daemon &\n");
        close(fd);
        return 1;
    }
    
    write(fd, msg, strlen(msg));
    
    char resp[16];
    read(fd, resp, sizeof(resp) - 1);
    close(fd);
    
    return 0;
}
