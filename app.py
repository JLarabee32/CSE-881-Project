import streamlit as st
import pandas as pd
import joblib
import numpy as np
import matplotlib.pyplot as plt
import shap

st.set_page_config(page_title="QB PPA Predictor", layout="wide")

@st.cache_resource
def load_model():
    return joblib.load('qb_xgb_model.pkl')

model = load_model()

FEATURES = [
    'years_in_college', 
    'prev_pass_yds', 
    'prev_pass_td', 
    'prev_avg_ppa', 
    'dest_off_ppa', 
    'dest_sp_offense', 
    'is_transfer'
]

st.sidebar.title("Navigation")
page = st.sidebar.radio("Go to", ["The Model", "Predict"])

# --- PAGE 1: EXPLAINER ---
if page == "The Model":
    st.title("QB Performance Explainer")
    st.write("""
    This model uses **XGBoost** to predict a Quarterback's PPA (Predicted Points Added) 
    for the upcoming season based on their previous performance.
    """)
    st.image('feature_importance.png')
    
    st.subheader("What drives the predictions?")
    st.write("""
    The chart below shows **SHAP values**. 
    - **Red** = High value for that stat.
    - **Blue** = Low value for that stat.
    - **Right side** = Pushes the prediction higher.
    - **Left side** = Pushes the prediction lower.
    """)

    st.image('shap_summary.png')

# --- PAGE 2: PREDICTION ---
elif page == "Predict":
    st.title("Predict QB Performance")
    st.write("Enter the player's stats from the previous season to predict their next PPA.")

    col1, col2 = st.columns(2)

    with col1:
        years_in_college = st.number_input("Years in College", value=2, step=1)
        prev_yds = st.number_input("Previous Pass Yards", value=2500, step=100)
        prev_tds = st.number_input("Previous Passing TDs", value=20, step=1)
        prev_ppa = st.number_input("Previous Avg PPA", value=0.30, step=0.01)
        
    with col2:
        dest_off_ppa = st.number_input("Destination Team's Previous PPA", value=0.30, step=0.01)
        dest_sp_offense = st.number_input("Destination Offense SP+ Rating", value=50.0, step=1.0)
        is_transfer = st.selectbox("Is the player a Transfer?", options=[0, 1], 
                                    format_func=lambda x: "Yes (1)" if x == 1 else "No (0)")

    # Create input dataframe
    input_data = pd.DataFrame([[
    years_in_college, 
    prev_yds, 
    prev_tds, 
    prev_ppa, 
    dest_off_ppa, 
    dest_sp_offense, 
    is_transfer]], columns=FEATURES)

    if st.button("Predict Post-PPA"):
        prediction = model.predict(input_data)[0]
        
        st.markdown("---")
        st.metric(label="Predicted Post-PPA", value=f"{prediction:.3f}")
        
        # Give context based on the prediction
        if is_transfer == 1:
            st.warning("Note: The 'Transfer Penalty' we saw in the SHAP analysis is being applied here.")
        else:
            st.success("Note: The model is rewarding this player for staying with their current team.")