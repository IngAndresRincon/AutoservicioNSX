let config = null;

export const loadConfig = async () => {
  const res = await fetch("/config.json");
  config = await res.json();
};

export const getConfig = () => config;