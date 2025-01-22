use clap::Parser;

#[derive(Parser)]
#[command(name = "sahuagin", version = "0.1.0", about = "Generator")]
struct Cli {
    /// Input file
    input: String,
}

fn main() {
    let args = Cli::parse();
    println!("Using input file: {}", args.input);
}
