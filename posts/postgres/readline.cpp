#include <iostream>
#include <readline/readline.h>
#include <readline/history.h>
#include <vector>
using namespace std;

struct readline_data
{
    int a;
    int b;
    readline_data *next;
};

int main()
{

    readline_data data;
    data.a = 10;
    data.b = 20;
    auto *box = new vector<int>;
    box->push_back(1);
    box->push_back(2);
    box->push_back(3);
    box->push_back(4);

    while (true)
    {
        char *p = readline("myshell:");
        add_history(p); // 加入历史列表
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