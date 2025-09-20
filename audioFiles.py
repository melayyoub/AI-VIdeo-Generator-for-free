import torch, numpy
from bark import SAMPLE_RATE, generate_audio, preload_models
from scipy.io.wavfile import write

# Patch for PyTorch 2.6+ checkpoint loading
torch.serialization.add_safe_globals([numpy.core.multiarray.scalar])

# Optional: override torch.load default
old_load = torch.load
def torch_load_wrapper(*args, **kwargs):
    kwargs["weights_only"] = False
    return old_load(*args, **kwargs)
torch.load = torch_load_wrapper

# Preload Bark models (first run will download models)
preload_models()

# Joke text (Egyptian slang)
joke = "مرة واحد راح للدكتور، قاله: يا دكتور، كل ما أشرب شاي عيني توجعني. الدكتور رد: طيب يا عم، شيل الملعقة من الكوباية الأول!"

# Generate audio with Arabic voice
audio_array = generate_audio(joke, history_prompt="ar_speaker")

# Save file to desktop
save_path = r"C:\Users\samsa\Desktop\egyptian_joke.wav"
write(save_path, SAMPLE_RATE, audio_array)

print(f"✅ Saved joke audio to: {save_path}")
