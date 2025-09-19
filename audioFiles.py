from bark import SAMPLE_RATE, generate_audio, preload_models
from scipy.io.wavfile import write

preload_models()
joke = "يا جماعة، واحد بيقول لصاحبه: عرفت إن مراتي بتعمل رجيم؟ قاله: باين، هي اللي عاملة رجيم ولا أنت اللي بتاكل أكلها؟"
audio_array = generate_audio(joke, history_prompt="ar_speaker")
write("egyptian_joke.wav", SAMPLE_RATE, audio_array)
