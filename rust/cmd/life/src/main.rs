use std::io::Write;
use std::{io, time::Duration};

use crossterm::{cursor, event, terminal, ExecutableCommand};
use crossterm::{event::KeyCode, style::Print, QueueableCommand};
use life::Universe;

fn main() -> crossterm::Result<()> {
    let (cols, rows) = terminal::size()?;
    let (width, height) = ((cols / 2) as u32, rows as u32);
    let mut universe = Universe::new(width, height);

    io::stdout()
        .queue(terminal::EnterAlternateScreen)?
        .queue(terminal::SetTitle("Conway's Life Game"))?
        .queue(terminal::Clear(terminal::ClearType::All))?
        .queue(cursor::Hide)?;

    let mut goon = true;
    loop {
        if event::poll(Duration::from_millis(10))? {
            if let event::Event::Key(event) = event::read()? {
                match event.code {
                    KeyCode::Esc => break,
                    KeyCode::Enter => goon = !goon,
                    _ => (),
                }
            }
        }

        if goon {
            universe.tick();
            io::stdout()
                .queue(terminal::Clear(terminal::ClearType::All))?
                .queue(Print(&universe))?
                .flush()?;
        }
    }

    io::stdout().execute(terminal::LeaveAlternateScreen)?;
    Ok(())
}
