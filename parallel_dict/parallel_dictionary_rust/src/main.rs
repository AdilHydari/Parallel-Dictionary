use std::collections::{HashMap, HashSet};
use std::fs::File;
use std::io::{BufRead, BufReader};
use std::thread;

use clap::Parser;
use indicatif::{ProgressBar, ProgressStyle};
use rayon::prelude::*;
use serde::Serialize;
use std::io::Write;
use walkdir::WalkDir;

/// Program to process books and count word occurrences.
#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Config {
    /// Directory containing the book files
    #[arg(
        short,
        long,
        default_value = "/home/adilh/classes/ECE451-Parallel/data/books"
    )]
    directory: String,

    /// Output file to save the results (JSON format)
    #[arg(short, long)]
    output: Option<String>,
}

#[derive(Debug, Serialize)]
struct Entry {
    word_count: usize,
    book_ids: HashSet<usize>,
}

#[derive(Debug, Serialize)]
struct Dictionary {
    dict: HashMap<String, Entry>,
}

impl Dictionary {
    fn new() -> Self {
        Dictionary {
            dict: HashMap::new(),
        }
    }

    fn insert(&mut self, word: &str, book_id: usize) {
        let entry = self.dict.entry(word.to_string()).or_insert_with(|| Entry {
            word_count: 0,
            book_ids: HashSet::new(),
        });
        entry.word_count += 1;
        entry.book_ids.insert(book_id);
    }

    fn merge(&mut self, other: &Dictionary) {
        for (word, other_entry) in &other.dict {
            let entry = self.dict.entry(word.clone()).or_insert_with(|| Entry {
                word_count: 0,
                book_ids: HashSet::new(),
            });
            entry.word_count += other_entry.word_count;
            entry.book_ids.extend(&other_entry.book_ids);
        }
    }

    fn remove_single_occurrences(&mut self) {
        self.dict.retain(|_, entry| entry.word_count > 1);
    }

    fn print(&self) {
        for (word, entry) in &self.dict {
            println!(
                "{}: {} times, in {} books",
                word,
                entry.word_count,
                entry.book_ids.len()
            );
        }
    }

    fn to_json(&self) -> serde_json::Result<String> {
        serde_json::to_string_pretty(&self.dict)
    }
}

fn split_to_words(text: &str) -> Vec<String> {
    let mut words = Vec::new();
    let mut start = None;
    for (i, c) in text.char_indices() {
        if c.is_alphabetic() {
            if start.is_none() {
                start = Some(i);
            }
        } else if let Some(s) = start {
            words.push(text[s..i].to_lowercase());
            start = None;
        }
    }
    if let Some(s) = start {
        words.push(text[s..].to_lowercase());
    }
    words
}

fn process_books(books: &[String], start_book_id: usize) -> Dictionary {
    let mut dict = Dictionary::new();
    for (i, book_file) in books.iter().enumerate() {
        let file = match File::open(book_file) {
            Ok(f) => f,
            Err(e) => {
                eprintln!("Failed to open file {}: {}", book_file, e);
                continue;
            }
        };
        let reader = BufReader::new(file);
        let book_id = start_book_id + i;
        for line in reader.lines() {
            if let Ok(line) = line {
                let words = split_to_words(&line);
                for word in words {
                    dict.insert(&word, book_id);
                }
            }
        }
    }
    dict
}

fn get_all_book_files(directory: &str) -> Vec<String> {
    let mut book_files = Vec::new();
    for entry in WalkDir::new(directory).into_iter().filter_map(Result::ok) {
        if entry.file_type().is_file() {
            if let Some(path_str) = entry.path().to_str() {
                book_files.push(path_str.to_string());
            }
        }
    }
    book_files
}

fn main() {
    // Parse command-line arguments
    let config = Config::parse();

    let books_directory = config.directory;
    let all_books = get_all_book_files(&books_directory);

    if all_books.is_empty() {
        eprintln!("No books found in the directory: {}", books_directory);
        return;
    }

    // Determine the number of threads to use
    let num_threads = thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(4);

    let total_books = all_books.len();
    let books_per_thread = (total_books + num_threads - 1) / num_threads;

    let pb = ProgressBar::new(total_books as u64);
    let style = ProgressStyle::default_bar()
        .template("[{elapsed_precise}] [{bar:40.cyan/blue}] {pos}/{len} Books")
        .unwrap_or_else(|e| {
            eprintln!("Failed to set progress bar template: {}", e);
            ProgressStyle::default_bar().progress_chars("#>-")
        })
        .progress_chars("#>-");

    pb.set_style(style);

    let mut handles = Vec::new();

    for i in 0..num_threads {
        let start_idx = i * books_per_thread;
        let end_idx = std::cmp::min(start_idx + books_per_thread, total_books);
        if start_idx >= end_idx {
            break;
        }
        let thread_books = all_books[start_idx..end_idx].to_vec();
        let start_book_id = start_idx;
        let pb_clone = pb.clone(); // Clone the progress bar for the thread

        let handle = thread::spawn(move || {
            let dict = process_books(&thread_books, start_book_id);
            for _ in 0..thread_books.len() {
                pb_clone.inc(1);
            }
            dict
        });
        handles.push(handle);
    }

    // Drop the main progress bar to allow it to be updated by threads
    drop(pb);

    let final_dict = handles
        .into_par_iter()
        .map(|handle| handle.join().unwrap())
        .reduce(
            || Dictionary::new(),
            |mut acc, dict| {
                acc.merge(&dict);
                acc
            },
        );

    let mut final_dict = final_dict;
    final_dict.remove_single_occurrences();

    // Output results
    if let Some(output_file) = config.output {
        match final_dict.to_json() {
            Ok(json_str) => match File::create(&output_file) {
                Ok(mut file) => {
                    if let Err(e) = file.write_all(json_str.as_bytes()) {
                        eprintln!("Failed to write to file {}: {}", output_file, e);
                    } else {
                        println!("Results successfully written to {}", output_file);
                    }
                }
                Err(e) => {
                    eprintln!("Failed to create file {}: {}", output_file, e);
                }
            },
            Err(e) => {
                eprintln!("Failed to serialize dictionary to JSON: {}", e);
            }
        }
    } else {
        final_dict.print();
    }
}
