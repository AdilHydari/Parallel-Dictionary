#include <iostream>
#include <fstream>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>
#include <future>
#include <algorithm>
#include <mutex>
#include <shared_mutex>

// Define a thread-safe unordered_map
class ConcurrentDictionary {
public:
    void insert(const std::string& word, int bookId) {
        std::unique_lock lock(mutex_);
        auto& entry = dict_[word];
        entry.wordCount++;
        entry.bookIds.insert(bookId);
    }

    void merge(const ConcurrentDictionary& other) {
        std::unique_lock lock(mutex_);
        for (const auto& [word, entry] : other.dict_) {
            auto& myEntry = dict_[word];
            myEntry.wordCount += entry.wordCount;
            myEntry.bookIds.insert(entry.bookIds.begin(), entry.bookIds.end());
        }
    }

    void removeSingleOccurrences() {
        std::unique_lock lock(mutex_);
        for (auto it = dict_.begin(); it != dict_.end();) {
            if (it->second.wordCount == 1) {
                it = dict_.erase(it);
            } else {
                ++it;
            }
        }
    }

    // For debugging purposes
    void print() const {
        for (const auto& [word, entry] : dict_) {
            std::cout << word << ": " << entry.wordCount << " times, in " << entry.bookIds.size() << " books\n";
        }
    }

private:
    struct Entry {
        int wordCount = 0;
        std::unordered_set<int> bookIds;
    };

    std::unordered_map<std::string, Entry> dict_;
    mutable std::shared_mutex mutex_;
};

// Helper function to split a string into words
std::vector<std::string> splitToWords(const std::string& text) {
    std::vector<std::string> words;
    size_t pos = 0, length = text.length();
    while (pos < length) {
        while (pos < length && !isalpha(text[pos])) ++pos;
        size_t start = pos;
        while (pos < length && isalpha(text[pos])) {
            text[pos] = tolower(text[pos]);
            ++pos;
        }
        if (start < pos) {
            words.emplace_back(text.substr(start, pos - start));
        }
    }
    return words;
}

// Function to process a set of books in a single thread
void processBooks(const std::vector<std::string>& books, ConcurrentDictionary& dict, int startBookId) {
    for (size_t i = 0; i < books.size(); ++i) {
        const auto& bookFile = books[i];
        std::ifstream file(bookFile);
        std::string line;
        int bookId = startBookId + static_cast<int>(i);
        while (std::getline(file, line)) {
            auto words = splitToWords(line);
            for (const auto& word : words) {
                dict.insert(word, bookId);
            }
        }
    }
}

int main() {
    // List of book files (add paths to all 110 books)
    std::vector<std::string> allBooks = {
        "/home/adilh/classes/ECE451-Parallel/data/books/pg55.txt", "/home/adilh/classes/ECE451-Parallel/data/books/pg5200.txt", // ...
    };

    // Use a thread pool size equal to the hardware concurrency
    const unsigned int numThreads = std::thread::hardware_concurrency();
    std::vector<std::future<void>> futures;
    std::vector<ConcurrentDictionary> dicts(numThreads);

    size_t totalBooks = allBooks.size();
    size_t booksPerThread = (totalBooks + numThreads - 1) / numThreads;

    // Launch tasks asynchronously
    for (unsigned int i = 0; i < numThreads; ++i) {
        size_t startIdx = i * booksPerThread;
        size_t endIdx = std::min(startIdx + booksPerThread, totalBooks);
        if (startIdx >= endIdx) break; // No more books to process

        std::vector<std::string> threadBooks(allBooks.begin() + startIdx, allBooks.begin() + endIdx);
        futures.emplace_back(std::async(std::launch::async, processBooks, threadBooks, std::ref(dicts[i]), static_cast<int>(startIdx)));
    }

    // Wait for all threads to finish
    for (auto& future : futures) {
        future.get();
    }

    // Merge dictionaries in parallel
    ConcurrentDictionary finalDict;
    for (const auto& dict : dicts) {
        finalDict.merge(dict);
    }

    // Remove words with only 1 occurrence
    finalDict.removeSingleOccurrences();

    // Output results or further processing
    finalDict.print();

    return 0;
}
