use std::{io, time::Duration};

use crossterm::{cursor, event, terminal, ExecutableCommand};
use crossterm::{event::KeyCode, style::Print};
use life::Universe;

fn main() -> crossterm::Result<()> {
    let (cols, rows) = terminal::size()?;
    let mut universe = Universe::new((cols / 2) as u32, rows as u32);

    io::stdout()
        .execute(terminal::EnterAlternateScreen)?
        .execute(terminal::SetTitle("康威生命游戏"))?
        .execute(terminal::DisableLineWrap)?
        .execute(cursor::Hide)?;

    let mut flag = true;
    loop {
        if event::poll(Duration::from_millis(250))? {
            if let event::Event::Key(event) = event::read()? {
                match event.code {
                    KeyCode::Esc => break,
                    KeyCode::Enter => flag = !flag,
                    _ => (),
                }
            }
        }

        if flag {
            universe.tick();
            io::stdout()
                .execute(terminal::Clear(terminal::ClearType::All))?
                .execute(Print(&universe))?;
        }
    }

    io::stdout().execute(terminal::LeaveAlternateScreen)?;
    Ok(())
}
