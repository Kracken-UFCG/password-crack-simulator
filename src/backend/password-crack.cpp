#include <iostream>
#include <string>

using namespace std;

string CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%&*()";

void crack(string target_password) {
    

}


int main(int argc, char* argv[]) {
    if (argc != 3) {
        cerr << "usage: ./password-crack <password> <regex_classify>\n";
        return 1;
    }

    string password = argv[1];
    string regex_classify = argv[2];

    cout << "Password: " << password << endl;
    cout << "Regex Classify: " << regex_classify << endl;

    return 0;
}