extern crate url;
extern crate ruby_bridge;

use std::collections::HashMap;
use url::Url;

#[derive(Eq, PartialEq, Debug)]
pub struct Analytics {
  hosts: HashMap<String, u64>,
  schemes: HashMap<String, u64>,
  endpoints: HashMap<String, u64>,
  total: u64
}

impl Analytics {
    pub fn new() -> Analytics {
        Analytics {
            hosts: HashMap::new(),
            endpoints: HashMap::new(),
            schemes: HashMap::new(),
            total: 0
        }
    }

    pub fn count(&self, url: &str) -> u64 {
        *self.endpoints.get(url).unwrap_or(&0)
    }
}

use ruby_bridge::Buffer;

#[no_mangle]
pub extern "C" fn report(analytics: &mut Analytics) -> Box<Buffer> {
    let str = format!("{:?}", analytics);
    Box::new(Buffer::from_string(str))
}

#[no_mangle]
pub extern "C" fn incr(analytics: &mut Analytics, buffer: &Buffer) -> u32 {
    let raw_url = buffer.as_slice();
    println!("{:?}", raw_url);

    let url = match Url::parse(raw_url) {
        Err(_) => return 1,
        Ok(url) => url
    };

    let host = match url.host() {
        None => return 1,
        Some(host) => host
    };

    increment(&mut analytics.hosts, &host.serialize()[..]);
    increment(&mut analytics.endpoints, raw_url);
    increment(&mut analytics.schemes, &url.scheme);

    analytics.total += 1;

    0
}

#[no_mangle]
pub extern "C" fn analytics() -> Box<Analytics> {
    Box::new(Analytics::new())
}

fn increment(hashmap: &mut HashMap<String, u64>, key: &str) {
    update(hashmap, key, || 1, |val| { *val += 1 });
}

fn update<F1, F2, T>(hashmap: &mut HashMap<String, T>, key: &str, initial: F1, update: F2)
    where F1: FnOnce() -> T, F2: FnOnce(&mut T)
{
    {
        let val = hashmap.get_mut(key);
        if val.is_some() {
            update(val.unwrap());
            return;
        }
    }

    hashmap.insert(key.to_string(), initial());
}
