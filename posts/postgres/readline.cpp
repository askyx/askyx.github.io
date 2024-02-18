#include <iostream>
#include <readline/readline.h>
#include <readline/history.h>
using namespace std;
int main()
{
    while (true)
    {
        char *p = readline("myshell:");
        add_history(p); //加入历史列表
        std::cout << p << std::endl;
        if (memcmp(p, "exit", 4) == 0)
        {
            rl_clear_history();
            free(p);
            return 0;
        }
        free(p);
    }
}