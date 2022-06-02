use crossterm::{cursor, event, style::Print, terminal};
use crossterm::{ExecutableCommand, QueueableCommand};
use life::Universe;
use std::{fmt::Display, io::Write, time::Duration};

fn main() -> crossterm::Result<()> {
    let mut world = World::new()?;
    loop {
        if event::poll(Duration::from_millis(500))? {
            handle_event(&mut world, event::read()?);
        }

        match world.status {
            Status::Over => return Ok(()),
            Status::Pause => (),
            Status::Running => world.render()?,
        }
    }
}

fn handle_event(world: &mut World, event: event::Event) {
    use event::{KeyCode, KeyModifiers};
    if let event::Event::Key(key) = event {
        let status = match (key.code, key.modifiers) {
            (KeyCode::Esc, _) => Status::Over,
            (KeyCode::Char('c'), KeyModifiers::CONTROL) => Status::Over,
            (KeyCode::Char(' '), _) => match world.status {
                Status::Running => Status::Pause,
                _ => Status::Running,
            },
            _ => return,
        };
        world.status = status;
    }
}

struct World {
    description: &'static str,
    status: Status,
    universe: Universe,
}

pub enum Status {
    Running,
    Pause,
    Over,
}

impl World {
    fn new() -> crossterm::Result<Self> {
        let (cols, rows) = World::create_terminal()?;
        let (width, height) = (cols as u32, rows as u32);
        Ok(World {
            description: "Space for pause, Esc and Ctrl + c for exit",
            status: Status::Running,
            universe: Universe::new(width / 2, height - 3),
        })
    }

    fn create_terminal() -> crossterm::Result<(u16, u16)> {
        terminal::enable_raw_mode()?;
        std::io::stdout().execute(cursor::Hide)?;
        terminal::size()
    }

    fn render(&mut self) -> crossterm::Result<()> {
        self.universe.tick();
        std::io::stdout()
            .queue(terminal::Clear(terminal::ClearType::All))?
            .queue(Print(self))?
            .flush()
    }

    fn reset_terminal() -> crossterm::Result<()> {
        std::io::stdout()
            .execute(terminal::Clear(terminal::ClearType::All))?
            .execute(cursor::Show)?;
        terminal::disable_raw_mode()
    }
}

impl Drop for World {
    fn drop(&mut self) {
        if let Err(e) = World::reset_terminal() {
            log::error!("drop world error: {}", e);
        }
    }
}

impl Display for World {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}\n\n{}", self.description, self.universe)
    }
}
