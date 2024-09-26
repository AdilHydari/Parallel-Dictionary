#include <algorithm>
#include <filesystem>
#include <fstream>
#include <functional>
#include <iostream>
#include <memory> // For std::unique_ptr
#include <mutex>
#include <shared_mutex>
#include <string>
#include <thread>
#include <unordered_map>
#include <unordered_set>
#include <vector>

// threaded logger (with a mutex)
class Logger {
public:
    template <typename T>
    void log(const T& message)
    {
        std::lock_guard<std::mutex> lock(logMutex_);
        std::cerr << message << std::endl;
    }

private:
    std::mutex logMutex_;
};

// sharding for faster speed, using unordered map
class ShardedConcurrentDictionary {
public:
    // constructor
    explicit ShardedConcurrentDictionary(size_t numShards = 16)
    {
        for (size_t i = 0; i < numShards; ++i) {
            shards_.emplace_back(std::make_unique<Shard>());
        }
    }

    // delete copy constructor and copy operator
    ShardedConcurrentDictionary(const ShardedConcurrentDictionary&) = delete;
    ShardedConcurrentDictionary& operator=(const ShardedConcurrentDictionary&) = delete;

    // delete move constructor and move operator
    ShardedConcurrentDictionary(ShardedConcurrentDictionary&&) = delete;
    ShardedConcurrentDictionary& operator=(ShardedConcurrentDictionary&&) = delete;

    void insert(const std::string& word, int bookId)
    {
        size_t shardIndex = getShardIndex(word);
        Shard& shard = *shards_[shardIndex];
        std::lock_guard<std::mutex> lock(shard.mutex);
        auto& entry = shard.dict[word];
        entry.wordCount++;
        entry.bookIds.insert(bookId);
    }

    void merge(const ShardedConcurrentDictionary& other)
    {
        for (size_t i = 0; i < shards_.size(); ++i) {
            const Shard& otherShard = *other.shards_[i];
            std::lock_guard<std::mutex> lockOther(otherShard.mutex);
            for (const auto& [word, entry] : otherShard.dict) {
                size_t shardIndex = getShardIndex(word);
                Shard& thisShard = *shards_[shardIndex];
                std::lock_guard<std::mutex> lockThis(thisShard.mutex);
                auto& myEntry = thisShard.dict[word];
                myEntry.wordCount += entry.wordCount;
                myEntry.bookIds.insert(entry.bookIds.begin(), entry.bookIds.end());
            }
        }
    }

    void removeSingleOccurrences()
    {
        for (auto& shardPtr : shards_) {
            Shard& shard = *shardPtr;
            std::lock_guard<std::mutex> lock(shard.mutex);
            for (auto it = shard.dict.begin(); it != shard.dict.end();) {
                if (it->second.wordCount == 1) {
                    it = shard.dict.erase(it);
                } else {
                    ++it;
                }
            }
        }
    }

    void print() const
    {
        for (const auto& shardPtr : shards_) {
            const Shard& shard = *shardPtr;
            std::lock_guard<std::mutex> lock(shard.mutex);
            for (const auto& [word, entry] : shard.dict) {
                std::cout << word << ": " << entry.wordCount
                          << " times, in " << entry.bookIds.size() << " books\n";
            }
        }
    }

private:
    struct Entry {
        int wordCount = 0;
        std::unordered_set<int> bookIds;
    };

    struct Shard {
        std::unordered_map<std::string, Entry> dict;
        mutable std::mutex mutex;
    };

    std::vector<std::unique_ptr<Shard>> shards_;

    size_t getShardIndex(const std::string& key) const
    {
        return std::hash<std::string> {}(key) % shards_.size();
    }
};

// Helper function to split a string into words without modifying the input
std::vector<std::string> splitToWords(const std::string& text)
{
    std::vector<std::string> words;
    words.reserve(text.size() / 5); // Assuming average word length of 5
    size_t pos = 0, length = text.length();
    while (pos < length) {
        // Skip non-alphabetic characters
        while (pos < length && !std::isalpha(static_cast<unsigned char>(text[pos])))
            ++pos;
        size_t start = pos;
        // Collect alphabetic characters
        while (pos < length && std::isalpha(static_cast<unsigned char>(text[pos]))) {
            ++pos;
        }
        if (start < pos) {
            // Extract the word and convert to lowercase
            std::string word = text.substr(start, pos - start);
            std::transform(word.begin(), word.end(), word.begin(),
                [](unsigned char c) { return std::tolower(c); });
            words.emplace_back(std::move(word));
        }
    }
    return words;
}

// Function to process a set of books in a single thread
void processBooks(const std::vector<std::string>& books, ShardedConcurrentDictionary& dict,
    int startBookId, Logger& logger)
{
    for (size_t i = 0; i < books.size(); ++i) {
        const auto& bookFile = books[i];
        std::ifstream file(bookFile);
        if (!file.is_open()) {
            logger.log("Failed to open file: " + bookFile);
            continue;
        }
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

// all files from directory, recursively
std::vector<std::string> getAllBookFiles(const std::string& directory, Logger& logger)
{
    std::vector<std::string> bookFiles;
    try {
        for (const auto& entry : std::filesystem::recursive_directory_iterator(directory)) {
            if (entry.is_regular_file()) {
                bookFiles.emplace_back(entry.path().string());
            }
        }
    } catch (const std::filesystem::filesystem_error& e) {
        logger.log(std::string("Filesystem error: ") + e.what());
    }
    return bookFiles;
}

int main(int argc, char* argv[])
{
    Logger logger;

    // cli options
    std::string booksDirectory = "/home/adilh/classes/ECE451-Parallel/data/books";
    size_t numShards = 16;

    if (argc >= 2) {
        booksDirectory = argv[1];
    }
    if (argc >= 3) {
        try {
            numShards = std::stoul(argv[2]);
            if (numShards == 0) {
                logger.log("Number of shards must be at least 1.");
                return 1;
            }
        } catch (const std::invalid_argument& e) {
            logger.log("Invalid number of shards provided.");
            return 1;
        } catch (const std::out_of_range& e) {
            logger.log("Number of shards provided is out of range.");
            return 1;
        }
    }

    std::vector<std::string> allBooks = getAllBookFiles(booksDirectory, logger);

    if (allBooks.empty()) {
        logger.log("No books provided.");
        return 1;
    }

    const unsigned int numThreads = std::max(1u, std::thread::hardware_concurrency());
    logger.log("Using " + std::to_string(numThreads) + " threads.");

    // dictionaries for each thread as unique_ptr
    std::vector<std::unique_ptr<ShardedConcurrentDictionary>> threadDicts;
    threadDicts.reserve(numThreads);
    for (unsigned int i = 0; i < numThreads; ++i) {
        threadDicts.emplace_back(std::make_unique<ShardedConcurrentDictionary>(numShards));
    }

    size_t totalBooks = allBooks.size();
    size_t booksPerThread = (totalBooks + numThreads - 1) / numThreads;

    std::vector<std::thread> threads;
    threads.reserve(numThreads);
    for (unsigned int i = 0; i < numThreads; ++i) {
        size_t startIdx = i * booksPerThread;
        size_t endIdx = std::min(startIdx + booksPerThread, totalBooks);
        if (startIdx >= endIdx)
            break; // no more books

        std::vector<std::string> threadBooks(allBooks.begin() + startIdx, allBooks.begin() + endIdx);
        threads.emplace_back(processBooks, std::move(threadBooks),
            std::ref(*threadDicts[i]), static_cast<int>(startIdx), std::ref(logger));
    }

    // merge all threads
    for (auto& thread : threads) {
        if (thread.joinable()) {
            thread.join();
        }
    }

    // merge dictionaries
    ShardedConcurrentDictionary finalDict(numShards);
    for (const auto& dictPtr : threadDicts) {
        finalDict.merge(*dictPtr);
    }

    // remove words with only 1 appearance
    finalDict.removeSingleOccurrences();

    finalDict.print();

    return 0;
}
