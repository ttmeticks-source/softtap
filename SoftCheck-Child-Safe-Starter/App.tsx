import 'react-native-url-polyfill/auto';
import React, { useEffect, useState } from 'react';
import {
  ActivityIndicator, Alert, KeyboardAvoidingView, Platform, SafeAreaView,
  ScrollView, StyleSheet, Text, TextInput, TouchableOpacity, View
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient, Session } from '@supabase/supabase-js';

const url = process.env.EXPO_PUBLIC_SUPABASE_URL ?? '';
const key = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY ?? '';
const supabase = createClient(url, key, {
  auth: { storage: AsyncStorage, autoRefreshToken: true, persistSession: true, detectSessionInUrl: false }
});

type Screen = 'welcome' | 'parent' | 'dashboard' | 'privacy';
type Mood = 'great' | 'okay' | 'meh' | 'low' | 'rough';
const moods: { key: Mood; emoji: string; label: string }[] = [
  { key: 'great', emoji: '🌞', label: 'Great' },
  { key: 'okay', emoji: '🌤️', label: 'Okay' },
  { key: 'meh', emoji: '☁️', label: 'Meh' },
  { key: 'low', emoji: '🌧️', label: 'Low' },
  { key: 'rough', emoji: '🫂', label: 'Rough' }
];

export default function App() {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);
  const [screen, setScreen] = useState<Screen>('welcome');
  const [isSignup, setIsSignup] = useState(true);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [mood, setMood] = useState<Mood | ''>('');
  const [note, setNote] = useState('');
  const [savedMood, setSavedMood] = useState<Mood | ''>('');
  const [guardianEmail, setGuardianEmail] = useState('');
  const [socialEnabled, setSocialEnabled] = useState(false);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setScreen(data.session ? 'dashboard' : 'welcome');
      setLoading(false);
    });
    const { data: listener } = supabase.auth.onAuthStateChange((_event, next) => {
      setSession(next);
      setScreen(next ? 'dashboard' : 'welcome');
    });
    return () => listener.subscription.unsubscribe();
  }, []);

  async function parentAuth() {
    if (!url || !key) {
      Alert.alert('Backend not connected', 'Copy .env.example to .env and add your Supabase URL and publishable/anon key.');
      return;
    }
    if (!email.trim() || password.length < 12) {
      Alert.alert('Parent account', 'Enter an adult email and a password with at least 12 characters.');
      return;
    }
    setLoading(true);
    const result = isSignup
      ? await supabase.auth.signUp({ email: email.trim(), password })
      : await supabase.auth.signInWithPassword({ email: email.trim(), password });
    setLoading(false);
    if (result.error) Alert.alert('Could not continue', result.error.message);
    else if (isSignup && !result.data.session) Alert.alert('Check your email', 'Confirm the parent/guardian email before signing in.');
  }

  async function saveLocalCheckin() {
    if (!mood) {
      Alert.alert('Choose a mood', 'Pick the mood that feels closest to today.');
      return;
    }
    // This early prototype deliberately keeps check-ins on this device only.
    // Do not sync child data until consent and the parent-management flow are verified.
    setSavedMood(mood);
    setNote('');
    Alert.alert('Saved on this device 💗', 'This prototype has not uploaded your mood or note.');
  }

  if (loading) return <SafeAreaView style={s.center}><ActivityIndicator size="large" color="#C45C9A" /></SafeAreaView>;

  if (!session) {
    if (screen === 'privacy') return <SafeAreaView style={s.safe}><ScrollView contentContainerStyle={s.content}>
      <Text style={s.brand}>softcheck <Text style={s.pink}>♡</Text></Text>
      <Text style={s.h1}>Privacy comes first</Text>
      <Text style={s.body}>SoftCheck is being built for children under 13. Before child accounts or online sharing can be switched on, the service needs a reviewed privacy policy, verified parental consent, a parent dashboard, data deletion tools, and tested access rules.</Text>
      <Text style={s.body}>This prototype does not ask a child for a name, birthday, photo, precise location, contacts, or personal email. Mood notes in demo mode stay on this device and are not sent to SoftCheck servers.</Text>
      <Text style={s.body}>A real release must explain what data is collected, why it is needed, who receives it, how long it is retained, and how a parent can review or delete it.</Text>
      <TouchableOpacity style={s.primary} onPress={() => setScreen('welcome')}><Text style={s.primaryText}>Back</Text></TouchableOpacity>
    </ScrollView></SafeAreaView>;

    if (screen === 'parent') return <SafeAreaView style={s.safe}><KeyboardAvoidingView style={s.content} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <Text style={s.brand}>softcheck <Text style={s.pink}>♡</Text></Text>
      <Text style={s.h1}>Parent or guardian setup</Text>
      <Text style={s.body}>An adult must start the setup. Creating this parent account does not yet create a child account or grant access to online social features.</Text>
      <TextInput style={s.input} placeholder="Parent/guardian email" placeholderTextColor="#9A8497" autoCapitalize="none" keyboardType="email-address" value={email} onChangeText={setEmail} />
      <TextInput style={s.input} placeholder="Password (12+ characters)" placeholderTextColor="#9A8497" secureTextEntry value={password} onChangeText={setPassword} />
      <TouchableOpacity style={s.primary} onPress={parentAuth}><Text style={s.primaryText}>{isSignup ? 'Create parent account' : 'Sign in as parent'}</Text></TouchableOpacity>
      <TouchableOpacity onPress={() => setIsSignup(!isSignup)}><Text style={s.link}>{isSignup ? 'Already set up? Sign in' : 'New parent? Create an account'}</Text></TouchableOpacity>
      <View style={s.notice}><Text style={s.noticeTitle}>Consent is not enabled yet</Text><Text style={s.small}>A verified-consent provider or reviewed server-side consent workflow must be connected before collecting child data. This screen is not itself parental consent.</Text></View>
      <TouchableOpacity onPress={() => setScreen('welcome')}><Text style={s.link}>Back</Text></TouchableOpacity>
    </KeyboardAvoidingView></SafeAreaView>;

    return <SafeAreaView style={s.safe}><ScrollView contentContainerStyle={s.content}>
      <View style={s.logo}><Text style={{ fontSize: 33 }}>♡</Text></View>
      <Text style={[s.brand, { textAlign: 'center' }]}>softcheck</Text>
      <Text style={[s.subtitle, { textAlign: 'center' }]}>little check-ins, real connection</Text>
      <View style={s.card}>
        <Text style={s.h1}>A soft place to land 🌷</Text>
        <Text style={s.body}>A gentle check-in app designed with children's privacy and safety in mind.</Text>
        <TouchableOpacity style={s.primary} onPress={() => setScreen('parent')}><Text style={s.primaryText}>Parent / guardian setup</Text></TouchableOpacity>
        <TouchableOpacity style={s.secondary} onPress={() => setScreen('privacy')}><Text style={s.secondaryText}>Read our privacy approach</Text></TouchableOpacity>
      </View>
      <View style={s.notice}><Text style={s.noticeTitle}>Online social features are off</Text><Text style={s.small}>Real child accounts, friend requests, messages, video uploads and push notifications remain locked until parental consent and safety controls are independently tested.</Text></View>
      <Text style={s.footer}>Demo build · Not ready for public child accounts</Text>
    </ScrollView></SafeAreaView>;
  }

  return <SafeAreaView style={s.safe}><ScrollView contentContainerStyle={s.content}>
    <View style={s.header}><View><Text style={s.brand}>softcheck <Text style={s.pink}>♡</Text></Text><Text style={s.subtitle}>parent setup area</Text></View><TouchableOpacity onPress={() => supabase.auth.signOut()}><Text style={s.link}>Sign out</Text></TouchableOpacity></View>
    <View style={s.card}>
      <Text style={s.h1}>Parent dashboard</Text>
      <Text style={s.body}>Signed in as {session.user.email}. This account is not yet verified as a parent and no child profile has been created.</Text>
      <View style={s.notice}><Text style={s.noticeTitle}>Setup status: not ready for child use</Text><Text style={s.small}>A verified adult consent flow and server-side child-account provisioning must be implemented before a child profile can be activated.</Text></View>
    </View>
    <View style={s.card}>
      <Text style={s.h2}>Social features</Text>
      <Text style={s.body}>Friend requests, accepted-friend chat, community posts, video sharing and push notifications are disabled in this starter. A parent must be able to enable/disable each feature, and server rules must enforce the choice.</Text>
      <Text style={s.small}>Current setting: {socialEnabled ? 'Demo toggle on (does not enable server features)' : 'Off'}</Text>
      <TouchableOpacity style={s.secondary} onPress={() => setSocialEnabled(!socialEnabled)}><Text style={s.secondaryText}>{socialEnabled ? 'Turn demo toggle off' : 'Try demo parent toggle'}</Text></TouchableOpacity>
    </View>
    <View style={s.card}>
      <Text style={s.h2}>Try a local mood check-in</Text>
      <Text style={s.body}>This demo check-in stays on the device. It is not synced to the database.</Text>
      <View style={s.moods}>{moods.map(m => <TouchableOpacity key={m.key} onPress={() => setMood(m.key)} style={[s.mood, mood === m.key && s.moodSelected]}><Text style={{ fontSize: 22 }}>{m.emoji}</Text><Text style={s.moodLabel}>{m.label}</Text></TouchableOpacity>)}</View>
      <TextInput style={[s.input, { minHeight: 70 }]} placeholder="Optional note (keep private info out)" placeholderTextColor="#9A8497" multiline value={note} onChangeText={setNote} maxLength={300} />
      <TouchableOpacity style={s.primary} onPress={saveLocalCheckin}><Text style={s.primaryText}>Save on this device</Text></TouchableOpacity>
      {!!savedMood && <Text style={s.link}>Last demo check-in: {moods.find(m => m.key === savedMood)?.label}</Text>}
    </View>
    <TouchableOpacity style={s.secondary} onPress={() => setScreen('privacy')}><Text style={s.secondaryText}>Privacy information</Text></TouchableOpacity>
    <Text style={s.footer}>No public profile, stranger discovery, chat, video upload or location access is enabled.</Text>
  </ScrollView></SafeAreaView>;
}

const s = StyleSheet.create({
  safe: { flex: 1, backgroundColor: '#FFF7FB' },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: '#FFF7FB' },
  content: { padding: 22, paddingBottom: 40, flexGrow: 1, justifyContent: 'center' },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 18 },
  logo: { width: 62, height: 62, borderRadius: 22, alignItems: 'center', justifyContent: 'center', backgroundColor: '#E7DDFE', alignSelf: 'center', marginBottom: 12 },
  brand: { fontSize: 29, fontWeight: '900', letterSpacing: -1, color: '#38263D' },
  pink: { color: '#C45C9A' },
  subtitle: { color: '#907E92', fontSize: 12, marginTop: 5 },
  h1: { color: '#38263D', fontSize: 22, fontWeight: '900', marginBottom: 12 },
  h2: { color: '#38263D', fontSize: 17, fontWeight: '800', marginBottom: 10 },
  body: { color: '#604B65', lineHeight: 22, marginBottom: 14 },
  small: { color: '#765D7C', lineHeight: 19, fontSize: 12 },
  card: { backgroundColor: '#FFFFFF', borderRadius: 22, padding: 18, marginTop: 15, borderWidth: 1, borderColor: '#F1DFEB' },
  input: { borderWidth: 1, borderColor: '#EEDCE9', backgroundColor: '#FFFBFE', borderRadius: 13, paddingHorizontal: 13, paddingVertical: 12, marginBottom: 10, color: '#38263D' },
  primary: { backgroundColor: '#D85F9E', borderRadius: 13, padding: 14, alignItems: 'center', marginTop: 6 },
  primaryText: { color: '#FFFFFF', fontWeight: '800' },
  secondary: { backgroundColor: '#F1E8FC', borderRadius: 13, padding: 13, alignItems: 'center', marginTop: 10 },
  secondaryText: { color: '#694E7C', fontWeight: '800' },
  link: { color: '#B64E91', fontWeight: '700', marginTop: 14, textAlign: 'center' },
  notice: { borderWidth: 1, borderColor: '#E8D7F3', backgroundColor: '#F5EDFC', borderRadius: 16, padding: 14, marginTop: 14 },
  noticeTitle: { color: '#60477B', fontWeight: '900', marginBottom: 6 },
  footer: { color: '#A08DA2', fontSize: 11, textAlign: 'center', lineHeight: 17, marginTop: 18 },
  moods: { flexDirection: 'row', gap: 6, marginBottom: 12 },
  mood: { flex: 1, alignItems: 'center', borderRadius: 12, paddingVertical: 10, backgroundColor: '#FFF7FB', borderWidth: 1, borderColor: '#F1DFEB' },
  moodSelected: { borderColor: '#D85F9E', backgroundColor: '#F9E4F1' },
  moodLabel: { fontSize: 10, color: '#604B65', marginTop: 4 }
});
